//
//  AnalyticsViewModel.swift
//  Notra
//

import Foundation

struct CategoryBreakdown {
    let category: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedPercentage: String {
        return String(format: "%.0f%%", percentage)
    }
}

final class AnalyticsViewModel {
    var selectedMonth: MonthMetadata

    private(set) var totalExpenses: Double = 0
    private(set) var totalIncomes: Double = 0
    private(set) var netBalance: Double = 0

    private(set) var expenseCategories: [CategoryBreakdown] = []
    private(set) var incomeCategories: [CategoryBreakdown] = []

    private(set) var topSpendingCategory: String?
    private(set) var highestSpendingDay: String?
    private(set) var highestSpendingDayAmount: Double = 0

    private(set) var expenseTransactionCount: Int = 0
    private(set) var incomeTransactionCount: Int = 0

    var hasData: Bool {
        return expenseTransactionCount > 0 || incomeTransactionCount > 0
    }

    init(month: MonthMetadata? = nil) {
        self.selectedMonth = month ?? MonthMetadata(date: Date())
    }

    func loadAnalytics() {
        let expenses = SessionCacheManager.shared.allExpenses
        let incomes = SessionCacheManager.shared.allIncomes

        let monthKey = selectedMonth.monthKey
        print("[Analytics] Screen opened")
        print("[Analytics] Selected month: \(selectedMonth.monthKey)")

        let monthExpenses = expenses.filter {
            MonthMetadata(date: $0.date).monthKey == monthKey
        }

        let monthIncomes = incomes.filter {
            MonthMetadata(date: $0.date).monthKey == monthKey
        }

        expenseTransactionCount = monthExpenses.count
        incomeTransactionCount = monthIncomes.count

        totalExpenses = monthExpenses.reduce(0) { $0 + $1.amount }
        totalIncomes = monthIncomes.reduce(0) { $0 + $1.amount }
        netBalance = totalIncomes - totalExpenses

        print("[Analytics] Expenses loaded: \(expenseTransactionCount) transactions, Total: \(formatCurrency(totalExpenses))")
        print("[Analytics] Incomes loaded: \(incomeTransactionCount) transactions, Total: \(formatCurrency(totalIncomes))")

        expenseCategories = computeCategoryBreakdown(from: monthExpenses)
        incomeCategories = computeCategoryBreakdown(from: monthIncomes)

        print("[Analytics] Category breakdown: \(expenseCategories.count) categories")

        if let top = expenseCategories.first {
            topSpendingCategory = "\(top.category) (\(top.formattedAmount))"
            print("[Analytics] Top spending: \(top.category) (\(top.formattedAmount))")
        }

        if let (day, amount) = findHighestSpendingDay(from: monthExpenses) {
            highestSpendingDay = day
            highestSpendingDayAmount = amount
            print("[Analytics] Highest spending day: \(day)")
        }
    }

    private func computeCategoryBreakdown(from transactions: [NormalizedTransaction]) -> [CategoryBreakdown] {
        var categoryTotals: [String: (amount: Double, count: Int)] = [:]

        for transaction in transactions {
            let category = transaction.category ?? "Uncategorized"
            let current = categoryTotals[category] ?? (amount: 0, count: 0)
            categoryTotals[category] = (amount: current.amount + transaction.amount, count: current.count + 1)
        }

        let total = transactions.reduce(0) { $0 + $1.amount }

        let breakdown = categoryTotals.map { key, value in
            let percentage = total > 0 ? (value.amount / total) * 100 : 0
            return CategoryBreakdown(
                category: key,
                amount: value.amount,
                percentage: percentage,
                transactionCount: value.count
            )
        }.sorted { $0.amount > $1.amount }

        return breakdown
    }

    private func findHighestSpendingDay(from transactions: [NormalizedTransaction]) -> (String, Double)? {
        var dayTotals: [String: Double] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        for transaction in transactions {
            let dayKey = dateFormatter.string(from: transaction.date)
            dayTotals[dayKey] = (dayTotals[dayKey] ?? 0) + transaction.amount
        }

        guard let maxDay = dayTotals.max(by: { $0.value < $1.value }),
              let date = dateFormatter.date(from: maxDay.key) else {
            return nil
        }

        return (displayFormatter.string(from: date), maxDay.value)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedTotalExpenses: String { formatCurrency(totalExpenses) }
    var formattedTotalIncomes: String { formatCurrency(totalIncomes) }
    var formattedNetBalance: String {
        let prefix = netBalance >= 0 ? "+" : "-"
        return "\(prefix)\(formatCurrency(abs(netBalance)))"
    }
}