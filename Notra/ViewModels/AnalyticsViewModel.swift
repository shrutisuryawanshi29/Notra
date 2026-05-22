//
//  AnalyticsViewModel.swift
//  Notra
//

import Foundation

private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
}

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

struct DailySpendingData {
    let day: Int
    let amount: Double

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct IncomeVsExpenseData {
    let totalIncome: Double
    let totalExpenses: Double
    var netDifference: Double { totalIncome - totalExpenses }

    var formattedIncome: String { formatCurrency(totalIncome) }
    var formattedExpenses: String { formatCurrency(totalExpenses) }
    var formattedNet: String { formatCurrency(abs(netDifference)) }
    var isPositive: Bool { netDifference >= 0 }
}

struct MonthlyTrendData {
    let month: String
    let expenses: Double
    let incomes: Double

    var formattedExpenses: String { formatCurrency(expenses) }
    var formattedIncomes: String { formatCurrency(incomes) }
}

enum AnalyticsViewMode: Int, CaseIterable {
    case overview = 0
    case expenses = 1
    case income = 2
    case trends = 3

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .expenses: return "Expenses"
        case .income: return "Income"
        case .trends: return "Trends"
        }
    }
}

enum AnalyticsTimeRange: Int, CaseIterable {
    case thisMonth = 0
    case last3Months = 1
    case last6Months = 2
    case cachedMonths = 3

    var title: String {
        switch self {
        case .thisMonth: return "This Month"
        case .last3Months: return "3M"
        case .last6Months: return "6M"
        case .cachedMonths: return "Cached"
        }
    }
}

struct MonthlyExpenseData {
    let month: String
    let monthKey: String
    let totalExpenses: Double
    let totalIncome: Double
    let categoryTotals: [String: Double]

    var formattedExpenses: String { formatCurrency(totalExpenses) }
    var formattedIncome: String { formatCurrency(totalIncome) }
}

final class AnalyticsViewModel {
    var selectedMonth: MonthMetadata
    var viewMode: AnalyticsViewMode = .overview
    var timeRange: AnalyticsTimeRange = .thisMonth

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

    private(set) var dailySpendingData: [DailySpendingData] = []
    private(set) var incomeVsExpenseData: IncomeVsExpenseData?
    private(set) var monthlyTrendData: [MonthlyTrendData] = []

    private(set) var monthlyExpenseComparisonData: [MonthlyExpenseData] = []
    private(set) var incomeVsExpenseOverTimeData: [MonthlyExpenseData] = []
    private(set) var categoryTrendData: [MonthlyExpenseData] = []
    private(set) var topTrendCategories: [String] = []

    private(set) var isLoading: Bool = false
    private(set) var hasError: Bool = false
    private(set) var errorMessage: String?

    private var monthExpenses: [NormalizedTransaction] = []
    private var monthIncomes: [NormalizedTransaction] = []

    var hasData: Bool {
        return expenseTransactionCount > 0 || incomeTransactionCount > 0
    }

    var hasDailySpending: Bool {
        return !dailySpendingData.isEmpty
    }

    var hasMonthlyTrend: Bool {
        return monthlyTrendData.count > 1
    }

    init(month: MonthMetadata? = nil) {
        self.selectedMonth = month ?? MonthMetadata(date: Date())
    }

    func loadAnalytics() {
        isLoading = true
        hasError = false
        errorMessage = nil

        let expenses = SessionCacheManager.shared.allExpenses
        let incomes = SessionCacheManager.shared.allIncomes

        let monthKey = selectedMonth.monthKey
        print("[Analytics] Screen opened")
        print("[Analytics] Selected month: \(selectedMonth.monthKey)")

        monthExpenses = expenses.filter {
            MonthMetadata(date: $0.date).monthKey == monthKey
        }

        monthIncomes = incomes.filter {
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

        dailySpendingData = computeDailySpending(from: monthExpenses)

        if totalExpenses > 0 || totalIncomes > 0 {
            incomeVsExpenseData = IncomeVsExpenseData(
                totalIncome: totalIncomes,
                totalExpenses: totalExpenses
            )
        }

        monthlyTrendData = computeMonthlyTrend()

        let rangeMonths = monthsForTimeRange()
        monthlyExpenseComparisonData = computeMonthlyExpenseData(for: rangeMonths)
        incomeVsExpenseOverTimeData = computeMonthlyExpenseData(for: rangeMonths)
        categoryTrendData = computeMonthlyExpenseData(for: rangeMonths)
        topTrendCategories = computeTopCategories(for: categoryTrendData)

        isLoading = false
        if expenses.isEmpty && incomes.isEmpty && SessionCacheManager.shared.isCachePopulated == false {
            hasError = true
            errorMessage = "No analytics yet. Add a transaction to get started."
        }

        print("[Analytics] Time range: \(timeRange.title), months: \(rangeMonths.count)")
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

    private func computeDailySpending(from transactions: [NormalizedTransaction]) -> [DailySpendingData] {
        var dayTotals: [Int: Double] = [:]

        for transaction in transactions {
            let day = Calendar.current.component(.day, from: transaction.date)
            dayTotals[day] = (dayTotals[day] ?? 0) + transaction.amount
        }

        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: DateComponents(year: selectedMonth.year, month: selectedMonth.month, day: 1))!)?.count ?? 30

        var result: [DailySpendingData] = []
        for day in 1...max(daysInMonth, 31) {
            let amount = dayTotals[day] ?? 0
            result.append(DailySpendingData(day: day, amount: amount))
        }

        return result
    }

    private func computeMonthlyTrend() -> [MonthlyTrendData] {
        let allExpenses = SessionCacheManager.shared.allExpenses
        let allIncomes = SessionCacheManager.shared.allIncomes
        let cachedMonths = SessionCacheManager.shared.getFetchedMonths()

        var result: [MonthlyTrendData] = []

        for month in cachedMonths.sorted(by: { $0.monthKey < $1.monthKey }) {
            let monthExpenses = allExpenses.filter {
                MonthMetadata(date: $0.date).monthKey == month.monthKey
            }
            let monthIncomes = allIncomes.filter {
                MonthMetadata(date: $0.date).monthKey == month.monthKey
            }

            let expenseTotal = monthExpenses.reduce(0) { $0 + $1.amount }
            let incomeTotal = monthIncomes.reduce(0) { $0 + $1.amount }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            var components = DateComponents()
            components.year = month.year
            components.month = month.month
            components.day = 1
            let displayDate = Calendar.current.date(from: components) ?? Date()
            let monthName = formatter.string(from: displayDate)

            result.append(MonthlyTrendData(
                month: monthName,
                expenses: expenseTotal,
                incomes: incomeTotal
            ))
        }

        return result
    }

    private func computeMonthlyExpenseData(for monthKeys: [String]) -> [MonthlyExpenseData] {
        let allExpenses = SessionCacheManager.shared.allExpenses
        let allIncomes = SessionCacheManager.shared.allIncomes

        var result: [MonthlyExpenseData] = []

        for monthKey in monthKeys {
            let monthExp = allExpenses.filter {
                MonthMetadata(date: $0.date).monthKey == monthKey
            }
            let monthInc = allIncomes.filter {
                MonthMetadata(date: $0.date).monthKey == monthKey
            }

            let expenseTotal = monthExp.reduce(0) { $0 + $1.amount }
            let incomeTotal = monthInc.reduce(0) { $0 + $1.amount }

            var catTotals: [String: Double] = [:]
            for tx in monthExp {
                let cat = tx.category ?? "Uncategorized"
                catTotals[cat] = (catTotals[cat] ?? 0) + tx.amount
            }

            let displayName = shortMonthName(for: monthKey)

            result.append(MonthlyExpenseData(
                month: displayName,
                monthKey: monthKey,
                totalExpenses: expenseTotal,
                totalIncome: incomeTotal,
                categoryTotals: catTotals
            ))
        }

        return result
    }

    private func shortMonthName(for monthKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: monthKey) else { return monthKey }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM"
        return displayFormatter.string(from: date)
    }

    private func computeTopCategories(for data: [MonthlyExpenseData], limit: Int = 4) -> [String] {
        var globalTotals: [String: Double] = [:]
        for item in data {
            for (cat, amount) in item.categoryTotals {
                globalTotals[cat] = (globalTotals[cat] ?? 0) + amount
            }
        }
        return globalTotals.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
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

    func topExpenseCategories(limit: Int = 5) -> [CategoryBreakdown] {
        return Array(expenseCategories.prefix(limit))
    }

    func topIncomeSources(limit: Int = 5) -> [CategoryBreakdown] {
        return Array(incomeCategories.prefix(limit))
    }

    var dailySpendingStats: (highestDay: String, highestAmount: Double, average: Double, spendingDays: Int, lowestDay: String?, lowestAmount: Double)? {
        let nonZeroDays = dailySpendingData.filter { $0.amount > 0 }
        guard !nonZeroDays.isEmpty else { return nil }

        let sorted = nonZeroDays.sorted { $0.amount > $1.amount }
        let highest = sorted[0]

        let total = nonZeroDays.reduce(0) { $0 + $1.amount }
        let average = total / Double(nonZeroDays.count)

        var lowest: (day: Int, amount: Double)? = nil
        if sorted.count > 1 {
            lowest = (sorted[sorted.count - 1].day, sorted[sorted.count - 1].amount)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        var components = DateComponents()
        components.year = selectedMonth.year
        components.month = selectedMonth.month
        components.day = highest.day
        let highestDateStr = dateFormatter.string(from: Calendar.current.date(from: components) ?? Date())

        var lowestDateStr: String? = nil
        if let lowestInfo = lowest {
            components.day = lowestInfo.day
            lowestDateStr = dateFormatter.string(from: Calendar.current.date(from: components) ?? Date())
        }

        return (highestDay: highestDateStr, highestAmount: highest.amount, average: average, spendingDays: nonZeroDays.count, lowestDay: lowestDateStr, lowestAmount: lowest?.amount ?? 0)
    }

    var hasExpenses: Bool {
        return expenseTransactionCount > 0
    }

    var hasIncomes: Bool {
        return incomeTransactionCount > 0
    }

    var canShowTrend: Bool {
        return monthlyTrendData.count > 1
    }

    var cachedMonthKeys: [String] {
        let months = SessionCacheManager.shared.getFetchedMonths()
        return months.map { $0.monthKey }.sorted()
    }

    var availableMonthCount: Int {
        return cachedMonthKeys.count
    }

    func monthsForTimeRange() -> [String] {
        let allCached = cachedMonthKeys.sorted()
        guard !allCached.isEmpty else { return [selectedMonth.monthKey] }

        switch timeRange {
        case .thisMonth:
            return [selectedMonth.monthKey]
        case .last3Months:
            return lastNMonths(from: allCached, count: 3)
        case .last6Months:
            return lastNMonths(from: allCached, count: 6)
        case .cachedMonths:
            return allCached
        }
    }

    private func lastNMonths(from cachedMonths: [String], count: Int) -> [String] {
        let targetMonths = generatePreviousMonthKeys(from: selectedMonth.monthKey, count: count)
        return targetMonths.filter { cachedMonths.contains($0) }.sorted()
    }

    private func generatePreviousMonthKeys(from monthKey: String, count: Int) -> [String] {
        var keys: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let startDate = formatter.date(from: monthKey) else { return [monthKey] }

        var components = DateComponents()
        for i in 0..<count {
            components.month = -i
            if let date = Calendar.current.date(byAdding: components, to: startDate) {
                keys.append(formatter.string(from: date))
            }
        }
        return keys.sorted()
    }

    func missingMonthsMessage() -> String? {
        let months = monthsForTimeRange()
        let allCached = cachedMonthKeys

        switch timeRange {
        case .thisMonth:
            return nil
        case .last3Months:
            if allCached.count < 2 {
                return "Only \(monthDisplayName(allCached.first ?? "")) is loaded. Load more months to compare trends."
            }
            return nil
        case .last6Months:
            if allCached.count < 2 {
                return "Trend charts need multiple months. Load previous months to unlock this view."
            }
            return nil
        case .cachedMonths:
            if allCached.count < 2 {
                return "Load another month to compare trends."
            }
            return nil
        }
    }

    private func monthDisplayName(_ monthKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: monthKey) else { return monthKey }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }

    var hasMultipleMonths: Bool {
        return monthsForTimeRange().count > 1
    }

    var spendingDaysCount: Int {
        return dailySpendingData.filter { $0.amount > 0 }.count
    }

    var spendingDaysMessage: String? {
        let count = spendingDaysCount
        guard count > 0, expenseTransactionCount > 0 else { return nil }
        if count == 1 {
            return "Spending happened on 1 day this month."
        } else if count < 4 {
            return "Spending happened on \(count) days this month."
        }
        return nil
    }

    var insightTopCategoryTitle: String {
        return "Your highest category this month"
    }

    var insightHighestDayTitle: String {
        return "The day with the most expenses"
    }

    var insightTotalExpensesTitle: String {
        return "Transactions tracked this month"
    }

    var insightTotalIncomeTitle: String {
        return "Income entries tracked this month"
    }

    var insightNetBalanceTitle: String {
        return "Income minus expenses"
    }

    func setViewMode(_ mode: AnalyticsViewMode) {
        viewMode = mode
    }

    func setTimeRange(_ range: AnalyticsTimeRange) {
        timeRange = range
        loadAnalytics()
    }
}