import Foundation

// MARK: - Gemini JSON Response (Decodable)

struct GeminiReceiptResponse: Decodable {
    var merchant: String?
    var platform: String?
    var date: String?
    var orderNumber: String?
    var currency: String?
    var items: [GeminiItemResponse]
    var summary: GeminiSummaryResponse?
    var adjustments: [GeminiAdjustmentResponse]?
    var warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case merchant, platform, date, orderNumber, currency
        case items, summary, adjustments, warnings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant)
        platform = try c.decodeIfPresent(String.self, forKey: .platform)
        date = try c.decodeIfPresent(String.self, forKey: .date)
        orderNumber = try c.decodeIfPresent(String.self, forKey: .orderNumber)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        items = (try? c.decode([GeminiItemResponse].self, forKey: .items)) ?? []
        summary = try? c.decode(GeminiSummaryResponse.self, forKey: .summary)
        adjustments = try? c.decode([GeminiAdjustmentResponse].self, forKey: .adjustments)
        warnings = try? c.decode([String].self, forKey: .warnings)
    }
}

struct GeminiItemResponse: Decodable {
    var name: String
    var quantity: Double?
    var unitPrice: Double?
    var finalPrice: Double
    var categoryHint: String?
    var rawText: String?

    enum CodingKeys: String, CodingKey {
        case name, quantity, unitPrice, finalPrice, categoryHint, rawText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        quantity = try? c.decode(Double.self, forKey: .quantity)
        unitPrice = try? c.decode(Double.self, forKey: .unitPrice)
        // finalPrice might be missing in some responses; default to 0
        finalPrice = (try? c.decode(Double.self, forKey: .finalPrice)) ?? 0
        categoryHint = try? c.decode(String.self, forKey: .categoryHint)
        rawText = try? c.decode(String.self, forKey: .rawText)
    }
}

struct GeminiSummaryResponse: Decodable {
    var itemsSubtotal: Double?
    var tax: Double?
    var serviceFee: Double?
    var deliveryFee: Double?
    var tip: Double?
    var discount: Double?
    var total: Double?
    var totalCharged: Double?
}

struct GeminiAdjustmentResponse: Decodable {
    var name: String
    var type: String?
    var amount: Double?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case name, type, amount
        case description = "description"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Adjustment"
        type = try? c.decode(String.self, forKey: .type)
        amount = try? c.decode(Double.self, forKey: .amount)
        description = try? c.decode(String.self, forKey: .description)
    }
}

// MARK: - App-Level Models

struct GeminiReceiptResult {
    var merchant: String?
    var platform: String?
    var date: Date?
    var orderNumber: String?
    var currency: String
    var items: [GeminiReceiptItem]
    var summary: GeminiReceiptSummary
    var adjustments: [GeminiReceiptAdjustment]
    var warnings: [String]
    var rawText: String

    var displayMerchant: String {
        if let m = merchant, let p = platform, !p.isEmpty, m != p {
            return "\(m) via \(p)"
        }
        return merchant ?? "Unknown Store"
    }
}

struct GeminiReceiptItem {
    var id: String
    var name: String
    var quantity: Double?
    var unitPrice: Double?
    var finalPrice: Double
    var categoryHint: String?
    var rawText: String?
    var classification: ReceiptItemClassification
    var isEditable: Bool
    var sharedWith: [String] = []
}

struct GeminiReceiptSummary {
    var itemsSubtotal: Double? = nil
    var tax: Double? = nil
    var serviceFee: Double? = nil
    var deliveryFee: Double? = nil
    var tip: Double? = nil
    var discount: Double? = nil
    var total: Double? = nil
    var totalCharged: Double? = nil

    var isEmpty: Bool {
        itemsSubtotal == nil && tax == nil && serviceFee == nil &&
        deliveryFee == nil && tip == nil && discount == nil &&
        total == nil && totalCharged == nil
    }
}

struct GeminiReceiptAdjustment {
    var name: String
    var type: String
    var amount: Double?
    var description: String?
}

// MARK: - Validator

struct GeminiReceiptValidator {

    static func validate(_ response: GeminiReceiptResponse, rawText: String) -> GeminiReceiptResult {
        var warnings = response.warnings ?? []

        let date = parseDate(response.date)

        var seen = Set<String>()
        let items = response.items
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.finalPrice >= 0 }
            .compactMap { item -> GeminiReceiptItem? in
                let name = item.name.trimmingCharacters(in: .whitespaces)
                let key = "\(name)|\(String(format: "%.2f", item.finalPrice))"
                guard !seen.contains(key) else { return nil }
                seen.insert(key)
                return GeminiReceiptItem(
                    id: UUID().uuidString,
                    name: name,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    finalPrice: item.finalPrice,
                    categoryHint: item.categoryHint,
                    rawText: item.rawText,
                    classification: .mine,
                    isEditable: true
                )
            }

        let itemSum = items.reduce(0.0) { $0 + $1.finalPrice }
        if let sub = response.summary?.itemsSubtotal, abs(itemSum - sub) > 0.10 {
            let mismatchMsg = "Item total ($\(String(format: "%.2f", itemSum))) differs from receipt subtotal ($\(String(format: "%.2f", sub))). Please review."
            if !warnings.contains(where: { $0.contains("differs from receipt subtotal") }) {
                warnings.append(mismatchMsg)
            }
        }

        if items.isEmpty {
            warnings.append("No receipt items were detected. You can add items manually.")
        }

        let s = response.summary
        let summary = GeminiReceiptSummary(
            itemsSubtotal: s?.itemsSubtotal,
            tax: s?.tax,
            serviceFee: s?.serviceFee,
            deliveryFee: s?.deliveryFee,
            tip: s?.tip,
            discount: s?.discount,
            total: s?.total,
            totalCharged: s?.totalCharged
        )

        let adjustments = (response.adjustments ?? []).map {
            GeminiReceiptAdjustment(name: $0.name, type: $0.type ?? "unknown",
                                    amount: $0.amount, description: $0.description)
        }

        print("[ReceiptValidation] Item count: \(items.count)")
        print("[ReceiptValidation] Item subtotal: \(String(format: "%.2f", itemSum))")
        print("[ReceiptValidation] Summary subtotal: \(s?.itemsSubtotal.map { String(format: "%.2f", $0) } ?? "nil")")
        print("[ReceiptValidation] Warnings: \(warnings)")

        return GeminiReceiptResult(
            merchant: response.merchant,
            platform: response.platform,
            date: date,
            orderNumber: response.orderNumber,
            currency: response.currency ?? "USD",
            items: items,
            summary: summary,
            adjustments: adjustments,
            warnings: warnings,
            rawText: rawText
        )
    }

    private static func parseDate(_ dateStr: String?) -> Date? {
        guard let str = dateStr else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: str)
    }
}
