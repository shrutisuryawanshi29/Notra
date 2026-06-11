//
//  GroupedTransactionSection.swift
//  Notra
//

import Foundation

// MARK: - Split Method

enum SplitMethodType: String, Codable, CaseIterable {
    case splitEqually = "splitEqually"
    case exactAmounts = "exactAmounts"
    case percent = "percent"
    case shares = "shares"
    case adjustment = "adjustment"

    var displayName: String {
        switch self {
        case .splitEqually: return "Split Equally"
        case .exactAmounts: return "Exact Amounts"
        case .percent: return "Percent"
        case .shares: return "Shares"
        case .adjustment: return "Adjustment"
        }
    }

    var chipLabel: String {
        switch self {
        case .splitEqually: return "Equal"
        case .exactAmounts: return "Exact"
        case .percent: return "Percent"
        case .shares: return "Shares"
        case .adjustment: return "Adjust"
        }
    }

    var helpText: String {
        switch self {
        case .splitEqually: return "Splits the paid amount evenly."
        case .exactAmounts: return "Enter your share or what they owe."
        case .percent: return "Enter your percent or their percent."
        case .shares: return "Legacy method kept for backward compatibility."
        case .adjustment: return "Add an extra amount that either you or they cover, then split the rest equally."
        }
    }

    static let uiCases: [SplitMethodType] = [.splitEqually, .exactAmounts, .percent, .adjustment]

    static func fromLegacy(_ legacy: String) -> SplitMethodType {
        switch legacy {
        case "50/50", "half", "Split Equally":
            return .splitEqually
        case "Custom Amount", "customAmount", "Exact Amounts":
            return .exactAmounts
        case "shares", "Shares":
            return .shares
        default:
            return SplitMethodType(rawValue: legacy) ?? .exactAmounts
        }
    }
}

// MARK: - Split Inputs

struct SplitInputs: Codable {
    var myShare: Double?
    var myPercent: Double?
    var theirPercent: Double?
    var myShares: Double?
    var theirShares: Double?
    var adjustmentAmount: Double?
    var adjustmentMode: String?
    var entryMode: String?
}

// MARK: - Split Calculator

struct SplitCalculator {

    struct SplitResult {
        let myShare: Double
        let theyOwe: Double
        let inputs: SplitInputs
        let type: SplitMethodType
    }

    static func calculate(
        paidAmount: Double,
        method: SplitMethodType,
        myShareExact: Double? = nil,
        theyOweExact: Double? = nil,
        myPercent: Double? = nil,
        theirPercent: Double? = nil,
        adjustmentAmount: Double? = nil,
        adjustmentMode: String? = nil
    ) -> SplitResult {
        guard paidAmount > 0 else {
            return SplitResult(myShare: 0, theyOwe: 0, inputs: SplitInputs(), type: method)
        }

        switch method {
        case .splitEqually:
            let half = paidAmount / 2
            return SplitResult(
                myShare: half,
                theyOwe: paidAmount - half,
                inputs: SplitInputs(),
                type: method
            )

        case .exactAmounts:
            var inputs = SplitInputs()
            if let theyOwe = theyOweExact {
                let owe = min(max(theyOwe, 0), paidAmount)
                inputs.myShare = paidAmount - owe
                inputs.entryMode = "theyOwe"
                return SplitResult(
                    myShare: paidAmount - owe,
                    theyOwe: owe,
                    inputs: inputs,
                    type: method
                )
            } else {
                let share = min(max(myShareExact ?? paidAmount, 0), paidAmount)
                inputs.myShare = share
                inputs.entryMode = "myShare"
                return SplitResult(
                    myShare: share,
                    theyOwe: paidAmount - share,
                    inputs: inputs,
                    type: method
                )
            }

        case .percent:
            var inputs = SplitInputs()
            if let theirPct = theirPercent {
                let pct = min(max(theirPct, 0), 100)
                let theirOwe = paidAmount * pct / 100
                inputs.theirPercent = pct
                inputs.entryMode = "theirPercent"
                return SplitResult(
                    myShare: paidAmount - theirOwe,
                    theyOwe: theirOwe,
                    inputs: inputs,
                    type: method
                )
            } else {
                let pct = min(max(myPercent ?? 100, 0), 100)
                let share = paidAmount * pct / 100
                inputs.myPercent = pct
                inputs.entryMode = "myPercent"
                return SplitResult(
                    myShare: share,
                    theyOwe: paidAmount - share,
                    inputs: inputs,
                    type: method
                )
            }

        case .adjustment:
            let extra = min(max(adjustmentAmount ?? 0, 0), paidAmount)
            let remainder = paidAmount - extra
            let mode = adjustmentMode ?? "extraIPay"
            let share: Double
            if mode == "extraTheyPay" {
                share = remainder / 2
            } else {
                share = extra + remainder / 2
            }
            var inputs = SplitInputs()
            inputs.adjustmentAmount = extra
            inputs.adjustmentMode = mode
            return SplitResult(
                myShare: share,
                theyOwe: paidAmount - share,
                inputs: inputs,
                type: method
            )

        case .shares:
            let half = paidAmount / 2
            return SplitResult(myShare: half, theyOwe: paidAmount - half, inputs: SplitInputs(), type: method)
        }
    }

    static func validate(method: SplitMethodType, paidAmount: Double, myPercent: Double? = nil, theirPercent: Double? = nil, adjustmentAmount: Double? = nil) -> String? {
        switch method {
        case .splitEqually:
            return nil
        case .exactAmounts:
            return nil
        case .percent:
            if let p = myPercent, (p < 0 || p > 100) {
                return "Percent must be between 0 and 100."
            }
            if let p = theirPercent, (p < 0 || p > 100) {
                return "Percent must be between 0 and 100."
            }
            return nil
        case .shares:
            return nil
        case .adjustment:
            guard let a = adjustmentAmount, a >= 0, a <= paidAmount else {
                return "Adjustment must be between 0 and \(Int(paidAmount))."
            }
            return nil
        }
    }
}

// MARK: - Split Participant & Item (Phase 2)

enum SettlementStatus: String, Codable {
    case pending
    case settled
}

struct SplitParticipant: Codable {
    let id: String
    let name: String
    let owes: Double
    var status: String?
    var settledAt: String?

    var settlementStatus: SettlementStatus {
        get { SettlementStatus(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owes, status, settledAt
    }
}

struct SplitItem: Codable {
    let name: String
    let price: Double
    let assignment: String
    let sharedWith: [String]
}

// MARK: - Split Metadata

struct SplitMetadata: Codable {
    let enabled: Bool
    let paidAmount: Double
    let myShare: Double
    let theyOwe: Double
    let type: String?
    let status: String?
    let splitWith: String?
    let inputs: SplitInputs?
    let version: Int?
    var participants: [SplitParticipant]?
    let items: [SplitItem]?
    let receiptMetadata: ReceiptScanMetadata?

    enum CodingKeys: String, CodingKey {
        case enabled, paidAmount, myShare, theyOwe, type, status, splitWith, inputs
        case version, participants, items, receiptMetadata
    }

    var resolvedType: SplitMethodType? {
        guard let t = type else { return nil }
        return SplitMethodType.fromLegacy(t)
    }

    var displayTypeName: String {
        if isMultiPersonReceipt { return "Multi-Person Split" }
        return resolvedType?.displayName ?? type?.capitalized ?? "Split"
    }

    var isMultiPersonReceipt: Bool {
        version == 2 && type == "receiptMultiPerson"
    }

    var multiPersonSubtitle: String? {
        guard isMultiPersonReceipt, let participants = participants, !participants.isEmpty else {
            return nil
        }
        if participants.count <= 2 {
            let parts = participants.map { "\($0.name) owes \(currencyStr($0.owes))" }
            return parts.joined(separator: " · ")
        }
        return "\(participants.count) people owe \(currencyStr(theyOwe))"
    }

    /// Build updated JSON string with modified participants (for settlement updates).
    /// Preserves all existing fields, only changes the participant status/settledAt.
    func buildUpdatedJSON(updatedParticipants: [SplitParticipant]) -> String? {
        var data: [String: Any] = [:]
        data["version"] = version ?? 2
        data["receipt"] = receiptMetadata.map { meta in
            [
                "source": meta.source,
                "merchant": meta.merchant as Any,
                "itemCount": meta.itemCount,
                "originalTotal": meta.originalTotal as Any
            ]
        }

        let splitData: [String: Any] = [
            "enabled": enabled,
            "paidAmount": paidAmount,
            "myShare": myShare,
            "theyOwe": theyOwe,
            "type": type as Any,
            "status": status as Any,
            "splitWith": splitWith as Any,
            "inputs": inputs as Any,
            "participants": updatedParticipants.map { p in
                [
                    "id": p.id,
                    "name": p.name,
                    "owes": p.owes,
                    "status": p.status as Any,
                    "settledAt": p.settledAt as Any
                ]
            },
            "items": items.map { items in
                items.map { i in
                    [
                        "name": i.name,
                        "price": i.price,
                        "assignment": i.assignment,
                        "sharedWith": i.sharedWith
                    ]
                }
            } as Any
        ]
        data["split"] = splitData

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        return jsonString
    }

    private func currencyStr(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: val)) ?? "$0.00"
    }
}

// MARK: - Grouped Transaction Section

struct GroupedTransactionSection {
    let date: String
    let displayDate: String
    let transactions: [NormalizedTransaction]
    let totalAmount: Double
}

struct NormalizedTransaction: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let paidAmount: Double?
    let category: String?
    let date: Date
    let databaseId: String
    let databaseRole: DatabaseRole
    let rawProperties: [String: NotionPropertyValue]?
    let splitMetadata: SplitMetadata?

    var isSplit: Bool {
        splitMetadata?.enabled == true
    }

    var reimbursementAmount: Double {
        if let split = splitMetadata, split.enabled {
            return split.theyOwe
        }
        if let paid = paidAmount, paid != amount {
            return paid - amount
        }
        return 0
    }

    var effectiveAmount: Double {
        if let split = splitMetadata, split.enabled {
            return split.myShare
        }
        return amount
    }

    var splitType: String? {
        splitMetadata?.type
    }

    var splitStatus: String? {
        splitMetadata?.status
    }

    var splitWith: String? {
        splitMetadata?.splitWith
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: effectiveAmount)) ?? "$0.00"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MonthMetadata: Codable {
    let year: Int
    let month: Int
    let monthKey: String

    init(date: Date) {
        let calendar = Calendar.current
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)
        self.monthKey = String(format: "%04d-%02d", year, month)
    }
}

// MARK: - Budget Utilization

enum BudgetStatus {
    case noBudget
    case safe
    case warning
    case overBudget
}

extension BudgetStatus {
    var sortOrder: Int {
        switch self {
        case .overBudget: return 0
        case .warning: return 1
        case .safe: return 2
        case .noBudget: return 3
        }
    }
}

struct BudgetCategoryItem {
    let categoryPageId: String
    let categoryName: String
    let iconEmoji: String?
    let spent: Double
    let budget: Double?

    var utilizationPercent: Double? {
        guard let budget = budget, budget > 0 else { return nil }
        return (spent / budget) * 100
    }

    var status: BudgetStatus {
        guard let budget = budget, budget > 0 else { return .noBudget }
        let pct = spent / budget
        if pct > 1.0 { return .overBudget }
        if pct >= 0.8 { return .warning }
        return .safe
    }
}

// MARK: - Income Snapshot

struct IncomeSnapshotData {
    let totalIncome: Double
    let totalCount: Int
    let mainSource: IncomeSourceSummary?
    let topSources: [IncomeSourceSummary]
    let hasIncome: Bool
}

struct IncomeSourceSummary {
    let name: String
    let amount: Double
    let count: Int
    let percentage: Double
}

struct BudgetUtilizationSummary {
    let totalBudget: Double
    let totalSpent: Double
    let overBudgetCount: Int
    let warningCount: Int
    let onTrackCount: Int
}