import Foundation

final class ReceiptParserService {

    static let shared = ReceiptParserService()

    private let dateFormatters: [DateFormatter] = {
        let formats = [
            "MM/dd/yyyy", "MM/dd/yy",
            "M/d/yyyy", "M/d/yy",
            "yyyy-MM-dd",
            "MMM dd, yyyy", "MMMM dd, yyyy",
            "dd MMM yyyy", "dd MMMM yyyy",
            "MM.dd.yyyy", "MM.dd.yy"
        ]
        return formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US")
            return f
        }
    }()

    // Lines that START with these words are summary/service rows, not purchasable items.
    // Matching uses word-boundary: prefix must be followed by space, colon, or end-of-string.
    private let summaryLinePrefixes: [String] = [
        "subtotal", "sub total", "sub-total",
        "tax", "sales tax", "hst", "gst", "vat",
        "total",
        "tip", "driver tip", "gratuity",
        "delivery", "free delivery", "standard delivery", "express delivery",
        "shipping", "handling",
        "service fee", "service charge",
        "fee", "fees",
        "discount", "promo", "promotion", "coupon",
        "savings", "you saved",
        "order#", "order #", "invoice",
        "buyer", "payment",
        "visa", "mastercard", "amex", "discover",
        "credit card", "debit card",
        "change", "balance", "approved",
        "surcharge", "convenience fee",
        "bag fee", "fuel surcharge"
    ]

    private let paymentLinePatterns: [String] = [
        "\\b(CASH|VISA|MASTERCARD|AMEX|DISCOVER|CREDIT|DEBIT)\\b",
        "\\b(CHANGE|BALANCE|APPROVED)\\b",
        "\\*\\*\\*.*\\*\\*\\*",
        "X+\\d{4}"
    ]

    private init() {}

    func parse(text: String) -> ReceiptParseResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var warnings: [String] = []
        var merchantName: String?
        var date: Date?
        var items: [ReceiptItem] = []
        var subtotal: Double?
        var tax: Double?
        var total: Double?
        var deliveryFee: Double?
        var deliveryCharged: Double?
        var tip: Double?

        let totalLines = lines.count

        // Phase 1: Merchant name from first few non-trivial lines
        for idx in 0..<min(5, totalLines) {
            let line = lines[idx]
            if let parsedDate = findDate(in: line) {
                date = parsedDate
            }
            if merchantName == nil && !isPaymentLine(line) && findDate(in: line) == nil && !isLikelyPrice(line) {
                let lc = line.lowercased()
                if !lc.hasPrefix("order") && !lc.hasPrefix("invoice") && !lc.hasPrefix("#") {
                    merchantName = line
                }
            }
        }

        // Phase 2: Find date if still missing
        if date == nil {
            for line in lines {
                if let parsedDate = findDate(in: line) {
                    date = parsedDate
                    break
                }
            }
        }

        // Phase 3: Classify and parse every line
        for line in lines {
            if isPaymentLine(line) { continue }
            if line.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil { continue }

            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            // --- Summary fields (specific checks first) ---

            // Subtotal
            if lower.hasPrefix("subtotal") || lower.hasPrefix("sub total") || lower.hasPrefix("sub-total") {
                subtotal = extractPrice(from: line)
                continue
            }

            // Tax
            if lower.hasPrefix("tax") || lower.contains("sales tax")
                || lower.hasPrefix("hst") || lower.hasPrefix("gst") || lower.hasPrefix("vat") {
                if let price = extractPrice(from: line) { tax = price }
                continue
            }

            // Total (after subtotal guard to avoid misclassification)
            if (lower.hasPrefix("total") || lower.contains(" total"))
                && !lower.hasPrefix("subtotal") && !lower.hasPrefix("sub total") {
                if let price = extractPrice(from: line) { total = price }
                continue
            }

            // Tip / gratuity
            if lower.hasPrefix("tip") || lower.hasPrefix("driver tip")
                || lower.hasPrefix("gratuity") || lower.contains("driver tip") {
                if let price = extractPrice(from: line) { tip = price }
                continue
            }

            // Delivery / shipping (may carry two prices: original fee + charged amount)
            if lower.hasPrefix("delivery") || lower.hasPrefix("free delivery")
                || lower.hasPrefix("shipping") || lower.hasPrefix("service fee")
                || lower.contains("delivery fee") || lower.contains("delivery from") {
                let prices = extractAllPrices(from: line)
                if prices.count >= 2 {
                    // e.g. "Free delivery from store $9.95 $0" → fee=9.95, charged=0
                    deliveryFee = prices.first
                    deliveryCharged = prices.last
                } else {
                    deliveryFee = prices.first
                    deliveryCharged = prices.first
                }
                continue
            }

            // General summary/service line check (catches everything else in the keyword list)
            if isSummaryLine(lower) { continue }

            // --- Item detection ---

            // Walmart format: "Product Name Qty N $price"
            if let walmartItem = extractWalmartItem(from: line) {
                let confidence = min(1.0, Double(walmartItem.name.count) / 5.0)
                items.append(ReceiptItem(
                    id: UUID().uuidString,
                    rawText: line,
                    name: walmartItem.name,
                    price: walmartItem.price,
                    classification: .mine,
                    confidence: confidence,
                    isEditable: true
                ))
                continue
            }

            // Standard format: name followed by price
            if let price = extractPrice(from: line) {
                let cleanName = extractItemName(from: line, price: price)
                if cleanName.isEmpty { continue }
                let confidence = min(1.0, Double(cleanName.count) / 5.0)
                items.append(ReceiptItem(
                    id: UUID().uuidString,
                    rawText: line,
                    name: cleanName,
                    price: price,
                    classification: .mine,
                    confidence: confidence,
                    isEditable: true
                ))
            }
        }

        // Phase 4: Validate — warn if item sum differs from receipt subtotal
        let itemSum = items.reduce(0.0) { $0 + $1.price }
        if let sub = subtotal, abs(itemSum - sub) > 0.05 {
            warnings.append(
                "Item total ($\(String(format: "%.2f", itemSum))) differs from receipt subtotal ($\(String(format: "%.2f", sub))). Please review."
            )
        }

        if items.isEmpty {
            warnings.append("No items detected. You can add them manually.")
        }

        if merchantName == nil {
            merchantName = "Unknown Store"
        }

        if total == nil && items.count <= 2 {
            warnings.append("Please verify the extracted items. Low confidence.")
        }

        return ReceiptParseResult(
            merchantName: merchantName,
            date: date,
            items: items,
            subtotal: subtotal,
            tax: tax,
            total: total,
            deliveryFee: deliveryFee,
            deliveryCharged: deliveryCharged,
            tip: tip,
            warnings: warnings,
            rawText: text
        )
    }

    // MARK: - Private Helpers

    /// Returns true when `lower` is a summary/service/payment line that should never be an item row.
    private func isSummaryLine(_ lower: String) -> Bool {
        for prefix in summaryLinePrefixes {
            if lower == prefix
                || lower.hasPrefix(prefix + " ")
                || lower.hasPrefix(prefix + ":") {
                return true
            }
        }
        return false
    }

    /// Parses Walmart-style lines: "Product Name Qty N $price"
    private func extractWalmartItem(from line: String) -> (name: String, price: Double)? {
        let pattern = "^(.+?)\\s+Qty\\s+\\d+\\s+\\$(\\d+\\.\\d{2})\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsRange = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, options: [], range: nsRange),
              match.numberOfRanges >= 3,
              let nameRange = Range(match.range(at: 1), in: line),
              let priceRange = Range(match.range(at: 2), in: line) else { return nil }
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        guard let price = Double(line[priceRange]) else { return nil }
        return (name: name, price: price)
    }

    /// Extracts all dollar amounts from a line, including bare "$0" with no decimal.
    private func extractAllPrices(from line: String) -> [Double] {
        let pattern = "\\$\\s*\\d+(?:\\.\\d{1,2})?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: line.utf16.count)
        return regex.matches(in: line, options: [], range: range).compactMap { match in
            let str = (line as NSString).substring(with: match.range)
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Double(str)
        }
    }

    private func findDate(in line: String) -> Date? {
        let clean = line.trimmingCharacters(in: .whitespaces)
        for formatter in dateFormatters {
            if let date = formatter.date(from: clean) { return date }
            let range = NSRange(location: 0, length: clean.utf16.count)
            let regex = try? NSRegularExpression(pattern: "\\d{1,2}[/\\.-]\\d{1,2}[/\\.-]\\d{2,4}")
            if let match = regex?.firstMatch(in: clean, options: [], range: range) {
                let dateStr = (clean as NSString).substring(with: match.range)
                if let date = formatter.date(from: dateStr) { return date }
            }
        }
        return nil
    }

    private func extractPrice(from line: String) -> Double? {
        let patterns = [
            "\\$?\\d+\\.\\d{2}\\s*$",
            "\\$?\\d+\\.\\d{2}(?=\\s|$)",
            "\\$\\d+(\\.\\d{1,2})?",
            "\\d+\\.\\d{2}"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.matches(in: line, options: [], range: range).last {
                    let str = (line as NSString).substring(with: match.range)
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    if let price = Double(str), price < 100000 { return price }
                }
            }
        }
        return nil
    }

    private func extractItemName(from line: String, price: Double) -> String {
        var name = line
        let priceStr = String(format: "%.2f", price)

        if let range = name.range(of: priceStr, options: .backwards) {
            name = String(name[name.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "$ "))

        if let regex = try? NSRegularExpression(pattern: "^\\d+\\s+") {
            let range = NSRange(location: 0, length: name.utf16.count)
            name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
        }
        name = name.trimmingCharacters(in: .whitespaces)

        if name.isEmpty || name.count < 2 { return "" }
        if isSummaryLine(name.lowercased()) { return "" }
        return name
    }

    private func isPaymentLine(_ line: String) -> Bool {
        let upper = line.uppercased().trimmingCharacters(in: .whitespaces)
        for pattern in paymentLinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: upper.utf16.count)
                if regex.firstMatch(in: upper, options: [], range: range) != nil { return true }
            }
        }
        return false
    }

    private func isLikelyPrice(_ line: String) -> Bool {
        return extractPrice(from: line) != nil
    }
}
