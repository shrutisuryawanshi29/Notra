import Foundation

struct SplitTrackerEntry {
    let transactionId: String
    let transactionTitle: String
    let date: Date
    let category: String?
    let amountOwed: Double
    let status: SettlementStatus
    let settledAt: String?
    let participantId: String
    let splitMetadata: SplitMetadata
    let transaction: NormalizedTransaction
}

struct SplitTrackerPersonGroup {
    let personId: String
    let personName: String
    let pendingTotal: Double
    let settledTotal: Double
    let entries: [SplitTrackerEntry]

    var totalOwed: Double { pendingTotal + settledTotal }
    var pendingCount: Int { entries.filter { $0.status == .pending }.count }
}
