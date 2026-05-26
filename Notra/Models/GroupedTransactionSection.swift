//
//  GroupedTransactionSection.swift
//  Notra
//

import Foundation

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
    let category: String?
    let date: Date
    let databaseId: String
    let databaseRole: DatabaseRole
    let rawProperties: [String: NotionPropertyValue]?

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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