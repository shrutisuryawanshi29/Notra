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

    private let ignoredLinePatterns: Set<String> = [
        "cash", "visa", "mastercard", "amex", "discover", "credit", "debit",
        "change", "balance", "approved", "signature", "subtotal", "tax",
        "total", "sale", "transaction", "receipt", "check", "coupon",
        "savings", "reward", "member", "loyalty", "earn", "save"
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

        var i = 0
        let totalLines = lines.count

        // Phase 1: Find merchant (first few non-empty lines, skip if looks like a header)
        for idx in 0..<min(5, totalLines) {
            let line = lines[idx]
            if let parsedDate = findDate(in: line) {
                date = parsedDate
            }
            if merchantName == nil && !isPaymentLine(line) && findDate(in: line) == nil && !isLikelyPrice(line) {
                merchantName = line
            }
        }

        // Phase 2: Find date if not found yet
        if date == nil {
            for line in lines {
                if let parsedDate = findDate(in: line) {
                    date = parsedDate
                    break
                }
            }
        }

        // Phase 3: Parse line items, subtotal, tax, total
        var seenPrices: [String: Int] = [:]
        var itemLines: [(text: String, price: Double, rawLine: String)] = []

        for line in lines {
            if isPaymentLine(line) { continue }
            if line.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil { continue }

            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip header/store info lines
            if lower.contains("store") || lower.contains("market") || lower.contains("pharmacy") {
                if findDate(in: line) == nil && !isLikelyPrice(line) {
                    continue
                }
            }

            // Detect subtotal
            if lower.contains("subtotal") || lower == "subtotal" {
                if let price = extractPrice(from: line) {
                    subtotal = price
                }
                continue
            }

            // Detect tax
            if lower.hasPrefix("tax") || lower.contains("sales tax") || lower.contains("tax ") {
                if let price = extractPrice(from: line) {
                    tax = price
                }
                continue
            }

            // Detect total
            if lower.hasPrefix("total") || lower.contains("total ") {
                if let price = extractPrice(from: line) {
                    total = price
                }
                continue
            }

            if lower.contains("subtotal") || lower.contains("tax") || lower.contains("total") {
                continue
            }

            if isIgnoredLine(lower) { continue }

            if let price = extractPrice(from: line) {
                let cleanName = extractItemName(from: line, price: price)
                if cleanName.isEmpty { continue }

                let dedupKey = "\(cleanName)|\(String(format: "%.2f", price))"
                seenPrices[dedupKey, default: 0] += 1

                let confidence = min(1.0, Double(cleanName.count) / 5.0)
                let item = ReceiptItem(
                    id: UUID().uuidString,
                    rawText: line,
                    name: cleanName,
                    price: price,
                    classification: .mine,
                    confidence: confidence,
                    isEditable: true
                )
                items.append(item)
                itemLines.append((text: cleanName, price: price, rawLine: line))
            }
        }

        // Phase 4: Validate totals
        if let subtotal = subtotal, let total = total {
            let sumItems = items.reduce(0) { $0 + $1.price }
            let diff = abs(total - sumItems)
            if diff > 0.5 && tax == nil {
                warnings.append("Item total (\(String(format: "%.2f", sumItems))) does not match receipt total (\(String(format: "%.2f", total))).")
            }
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
            warnings: warnings,
            rawText: text
        )
    }

    // MARK: - Private Helpers

    private func findDate(in line: String) -> Date? {
        let clean = line.trimmingCharacters(in: CharacterSet.whitespaces)
        for formatter in dateFormatters {
            if let date = formatter.date(from: clean) {
                return date
            }
            // Try to extract date from within the line
            let range = NSRange(location: 0, length: clean.utf16.count)
            let regex = try? NSRegularExpression(pattern: "\\d{1,2}[/\\.-]\\d{1,2}[/\\.-]\\d{2,4}")
            if let match = regex?.firstMatch(in: clean, options: [], range: range) {
                let dateStr = (clean as NSString).substring(with: match.range)
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
        }
        return nil
    }

    private func extractPrice(from line: String) -> Double? {
        // Find dollar amounts: $X.XX, X.XX at end of line
        let patterns = [
            "\\$?\\d+\\.\\d{2}\\s*$",
            "\\$?\\d+\\.\\d{2}(?=\\s|$)",
            "\\$\\d+(\\.\\d{1,2})?",
            "\\d+\\.\\d{2}"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: line.utf16.count)
                let matches = regex.matches(in: line, options: [], range: range)
                if let match = matches.last {
                    let priceStr = (line as NSString).substring(with: match.range)
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    if let price = Double(priceStr) {
                        // Filter out prices that are too large (likely not item prices)
                        if price < 100000 {
                            return price
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractItemName(from line: String, price: Double) -> String {
        var name = line
        let priceStr = String(format: "%.2f", price)

        // Remove price from end of line
        if let range = name.range(of: priceStr, options: .backwards) {
            name = String(name[name.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Remove $ prefix if present at end
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "$ "))

        // Remove leading numbers/quantities
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\s+") {
            let range = NSRange(location: 0, length: name.utf16.count)
            name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
        }

        name = name.trimmingCharacters(in: .whitespaces)

        // Filter out obvious non-item names
        if name.isEmpty || name.count < 2 { return "" }
        if ignoredLinePatterns.contains(name.lowercased()) { return "" }

        return name
    }

    private func isPaymentLine(_ line: String) -> Bool {
        let upper = line.uppercased().trimmingCharacters(in: .whitespaces)
        for pattern in paymentLinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: upper.utf16.count)
                if regex.firstMatch(in: upper, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    private func isIgnoredLine(_ lower: String) -> Bool {
        for pattern in ignoredLinePatterns {
            if lower == pattern || lower.hasPrefix(pattern) {
                return true
            }
        }
        return false
    }

    private func isLikelyPrice(_ line: String) -> Bool {
        return extractPrice(from: line) != nil
    }
}
