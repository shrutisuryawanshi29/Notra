import Foundation

enum ReceiptItemClassification: String, Codable, CaseIterable {
    case mine = "mine"
    case shared = "shared"
    case ignore = "ignore"
}

struct ReceiptItem: Identifiable, Codable {
    var id: String
    var rawText: String
    var name: String
    var price: Double
    var classification: ReceiptItemClassification
    var confidence: Double
    var isEditable: Bool
}

struct ReceiptParseResult {
    var merchantName: String?
    var date: Date?
    var items: [ReceiptItem]
    var subtotal: Double?
    var tax: Double?
    var total: Double?
    var deliveryFee: Double? = nil        // original listed delivery fee
    var deliveryCharged: Double? = nil    // final charged amount (0 if free)
    var tip: Double? = nil
    var warnings: [String]
    var rawText: String
}

struct ReceiptScanMetadata: Codable {
    let source: String
    let merchant: String?
    let itemCount: Int
    let originalTotal: Double?
}

struct ReceiptSplitSummary {
    var personalTotal: Double
    var sharedTotal: Double
    var myShare: Double
    var theyOwe: Double
    var splitMethod: SplitMethodType
    var includeTaxProportionally: Bool
    var personalTax: Double
    var sharedTax: Double
}
