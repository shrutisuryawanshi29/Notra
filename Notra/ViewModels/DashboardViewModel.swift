//
//  DashboardViewModel.swift
//  Notra
//

import Foundation

protocol DashboardViewModelDelegate: AnyObject {
    func didStartLoading()
    func didFinishLoading(success: Bool, error: Error?)
    func didUpdateProgress(current: Int, total: Int)
    func didUpdateMonthSelection()
}

final class DashboardViewModel {
    weak var delegate: DashboardViewModelDelegate?

    private let token: String
    private let columnMappingService = ColumnMappingService.shared
    private let dataFetcher = NotionDataFetcher.shared
    private let normalizer = TransactionNormalizer.shared
    private let notionService = NotionService.shared

    private var expenseMappings: [DatabaseMappingData] = []
    private var incomeMappings: [DatabaseMappingData] = []

    private var relationLookupMap: [String: [String: String]] = [:]
    private var categoryPagesByDataSource: [String: [NotionPage]] = [:]
    private(set) var budgetCategories: [BudgetCategoryItem] = []
    private(set) var budgetSummary: BudgetUtilizationSummary?

    private var allExpenses: [NormalizedTransaction] = []
    private var allIncomes: [NormalizedTransaction] = []

    var selectedMonth: MonthMetadata {
        didSet {
            updateSelectedMonthTotals()
            computeBudgetUtilization()
            delegate?.didUpdateMonthSelection()
        }
    }

    var selectedMonthExpenses: Double = 0
    var selectedMonthIncomes: Double = 0
    var selectedMonthExpensesCount: Int = 0
    var selectedMonthIncomesCount: Int = 0

    var balance: Double {
        return selectedMonthIncomes - selectedMonthExpenses
    }

    // MARK: - Dashboard Section Data

    var selectedMonthExpensesList: [NormalizedTransaction] {
        allExpenses.filter { MonthMetadata(date: $0.date).monthKey == selectedMonth.monthKey }
    }

    var selectedMonthIncomesList: [NormalizedTransaction] {
        allIncomes.filter { MonthMetadata(date: $0.date).monthKey == selectedMonth.monthKey }
    }

    var recentTransactions: [NormalizedTransaction] {
        let combined = selectedMonthExpensesList + selectedMonthIncomesList
        let sorted = combined.sorted { $0.date > $1.date }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.id).inserted }.prefix(5).map { $0 }
    }

    var largestExpense: NormalizedTransaction? {
        selectedMonthExpensesList.max { $0.amount < $1.amount }
    }

    var mostUsedCategory: (name: String, count: Int)? {
        let categories = selectedMonthExpensesList.compactMap { $0.category }.filter { !$0.isEmpty }
        guard !categories.isEmpty else { return nil }
        let counts = Dictionary(grouping: categories, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    var uncategorizedCount: Int {
        selectedMonthExpensesList.filter { $0.category == nil || $0.category!.isEmpty }.count
    }

    var hasBudgetData: Bool {
        !budgetCategories.isEmpty
    }

    var hasBudgetSetup: Bool {
        let expenseMappings = columnMappingService.loadDatabaseMappings().values.filter { $0.role == .expense }
        return expenseMappings.contains { $0.columnMapping?.categoryRelationDataSourceId != nil }
    }

    var statusInfo: DashboardStatusInfo {
        if selectedMonthExpenses == 0 && selectedMonthIncomes == 0 {
            return DashboardStatusInfo(
                mainText: "No transactions yet for this month",
                subText: "Add your first expense or income",
                footerText: "0 expenses · 0 income entries",
                balance: 0,
                hasIncome: false,
                hasExpenses: false
            )
        }

        if selectedMonthIncomes == 0 {
            let exCount = selectedMonthExpensesCount
            return DashboardStatusInfo(
                mainText: "No income recorded this month",
                subText: "Add income to calculate savings rate",
                footerText: "\(exCount) expense\(exCount == 1 ? "" : "s") · 0 income entries",
                balance: balance,
                hasIncome: false,
                hasExpenses: exCount > 0
            )
        }

        let savingsRate = (balance / selectedMonthIncomes) * 100
        let absRate = abs(savingsRate)
        let pctText = privateFormatPercent(absRate)

        if balance >= 0 {
            return DashboardStatusInfo(
                mainText: "You saved \(privateFormatCurrency(balance)) this month",
                subText: "Income is higher than expenses by \(pctText)",
                footerText: "\(selectedMonthExpensesCount) expense\(selectedMonthExpensesCount == 1 ? "" : "s") · \(selectedMonthIncomesCount) income entries",
                balance: balance,
                hasIncome: true,
                hasExpenses: selectedMonthExpensesCount > 0
            )
        } else {
            return DashboardStatusInfo(
                mainText: "You spent \(privateFormatCurrency(abs(balance))) more than you earned",
                subText: "Expenses are higher than income by \(pctText)",
                footerText: "\(selectedMonthExpensesCount) expense\(selectedMonthExpensesCount == 1 ? "" : "s") · \(selectedMonthIncomesCount) income entries",
                balance: balance,
                hasIncome: true,
                hasExpenses: selectedMonthExpensesCount > 0
            )
        }
    }

    private func privateFormatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: abs(value))) ?? "$0.00"
    }

    private func privateFormatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
    }

    var availableMonths: [MonthMetadata] = []

    init(token: String) {
        self.token = token
        self.selectedMonth = MonthMetadata(date: Date())
    }

    func loadData() {
        delegate?.didStartLoading()

        allExpenses = []
        allIncomes = []

        let mappings = columnMappingService.loadDatabaseMappings()
        expenseMappings = mappings.values.filter { $0.role == .expense && $0.columnMapping != nil }
        incomeMappings = mappings.values.filter { $0.role == .income && $0.columnMapping != nil }

        if expenseMappings.isEmpty && incomeMappings.isEmpty {
            delegate?.didFinishLoading(success: false, error: NSError(domain: "Notra", code: 1, userInfo: [NSLocalizedDescriptionKey: "No configured databases found"]))
            return
        }

        fetchRelationTargetDatabases { [weak self] in
            self?.fetchAllTransactionData()
        }
    }

    func selectMonth(_ month: MonthMetadata) {
        selectedMonth = month
    }

    private func updateSelectedMonthTotals() {
        let filteredExpenses = allExpenses.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == selectedMonth.monthKey
        }
        selectedMonthExpenses = filteredExpenses.reduce(0) { $0 + $1.amount }
        selectedMonthExpensesCount = filteredExpenses.count

        let filteredIncomes = allIncomes.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == selectedMonth.monthKey
        }
        selectedMonthIncomes = filteredIncomes.reduce(0) { $0 + $1.amount }
        selectedMonthIncomesCount = filteredIncomes.count
    }

    private func updateAvailableMonths() {
        var monthKeys = Set<String>()

        for transaction in allExpenses + allIncomes {
            let month = MonthMetadata(date: transaction.date)
            monthKeys.insert(month.monthKey)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        availableMonths = monthKeys.compactMap { key in
            guard let date = formatter.date(from: key) else { return nil }
            return MonthMetadata(date: date)
        }.sorted { $0.monthKey > $1.monthKey }

        if availableMonths.isEmpty {
            availableMonths = [MonthMetadata(date: Date())]
        }
    }

private func fetchRelationTargetDatabases(completion: @escaping () -> Void) {
        var relationDataSourceIds: Set<String> = []

        for mapping in expenseMappings {
            if let relationDataSourceId = mapping.columnMapping?.categoryRelationDataSourceId {
                print("[DashboardViewModel] Found relation data source for expense: \(relationDataSourceId)")
                relationDataSourceIds.insert(relationDataSourceId)
            }
        }

        for mapping in incomeMappings {
            if let relationDataSourceId = mapping.columnMapping?.categoryRelationDataSourceId {
                print("[DashboardViewModel] Found relation data source for income: \(relationDataSourceId)")
                relationDataSourceIds.insert(relationDataSourceId)
            }
        }

        print("[DashboardViewModel] Total relation data sources to fetch: \(relationDataSourceIds.count)")

        if relationDataSourceIds.isEmpty {
            print("[DashboardViewModel] No relation target data sources found")
            completion()
            return
        }

        let group = DispatchGroup()

        for dsId in relationDataSourceIds {
            group.enter()

            if let cachedData = SessionCacheManager.shared.getCategoryLookup(for: dsId) {
                relationLookupMap[dsId] = cachedData
                print("[DashboardViewModel] Using cached category lookup for data source: \(dsId)")
                group.leave()
            } else {
                print("[DashboardViewModel] Cache miss, fetching category data source: \(dsId)")
                print("[DashboardViewModel] Calling queryDataSource for: \(dsId)")
                notionService.queryDataSource(dataSourceId: dsId, token: token) { [weak self] result in
                    defer { group.leave() }

                    switch result {
                    case .success(let pages):
                        self?.categoryPagesByDataSource[dsId] = pages
                        var lookup: [String: String] = [:]
                        for page in pages {
                            let extractedTitle = self?.extractTitle(from: page) ?? String(page.id.prefix(8))
                            print("[DashboardViewModel] Page ID: \(page.id), Extracted title: \(extractedTitle)")
                            lookup[page.id] = extractedTitle
                        }
                        self?.relationLookupMap[dsId] = lookup
                        SessionCacheManager.shared.setCategoryLookup(for: dsId, lookup: lookup)
                        SessionCacheManager.shared.saveRelationTargetData(databaseId: dsId, lookup: lookup)
                        print("[DashboardViewModel] Cached \(lookup.count) items for data source: \(dsId)")
                    case .failure(let error):
                        print("[DashboardViewModel] FAILED to fetch data source \(dsId): \(error.localizedDescription)")
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    private func fetchAllTransactionData() {
        let totalDatabases = expenseMappings.count + incomeMappings.count
        var completed = 0

        let group = DispatchGroup()

        for mapping in expenseMappings {
            group.enter()
            fetchAndNormalize(database: mapping, role: .expense) { expenses in
                var seen = Set<String>()
                var uniqueExpenses: [NormalizedTransaction] = []
                for expense in expenses {
                    if !seen.contains(expense.id) {
                        seen.insert(expense.id)
                        uniqueExpenses.append(expense)
                    }
                }
                let existingIds = Set(self.allExpenses.map { $0.id })
                let newExpenses = uniqueExpenses.filter { !existingIds.contains($0.id) }
                self.allExpenses.append(contentsOf: newExpenses)
                completed += 1
                self.delegate?.didUpdateProgress(current: completed, total: totalDatabases)
                group.leave()
            }
        }

        for mapping in incomeMappings {
            group.enter()
            fetchAndNormalize(database: mapping, role: .income) { incomes in
                var seen = Set<String>()
                var uniqueIncomes: [NormalizedTransaction] = []
                for income in incomes {
                    if !seen.contains(income.id) {
                        seen.insert(income.id)
                        uniqueIncomes.append(income)
                    }
                }
                let existingIds = Set(self.allIncomes.map { $0.id })
                let newIncomes = uniqueIncomes.filter { !existingIds.contains($0.id) }
                self.allIncomes.append(contentsOf: newIncomes)
                completed += 1
                self.delegate?.didUpdateProgress(current: completed, total: totalDatabases)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.processResults()
        }
    }

    private func fetchAndNormalize(database: DatabaseMappingData, role: DatabaseRole, completion: @escaping ([NormalizedTransaction]) -> Void) {
        dataFetcher.fetchAllRows(databaseId: database.databaseId, token: token) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let rows):
                self.normalizer.setToken(self.token)
                self.normalizer.setRelationLookupMap(self.relationLookupMap)
                self.normalizer.normalize(rows: rows, mapping: database, role: role) { transactions in
                    completion(transactions)
                }
            case .failure:
                completion([])
            }
        }
    }

    private func processResults() {
        SessionCacheManager.shared.populateCache(expenses: allExpenses, incomes: allIncomes)
        SessionCacheManager.shared.setLastLoadedMonth(Date())

        updateAvailableMonths()
        SessionCacheManager.shared.setFetchedMonths(availableMonths)
        updateSelectedMonthTotals()
        computeBudgetUtilization()

        selectedMonth = availableMonths.first ?? MonthMetadata(date: Date())

        print("[DashboardViewModel] Cache retrieval success")
        delegate?.didFinishLoading(success: true, error: nil)
    }

    func getCacheSummary() -> String {
        return SessionCacheManager.shared.getTransactionSummary()
    }

    func getMonthDisplayString(for month: MonthMetadata) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var components = DateComponents()
        components.year = month.year
        components.month = month.month
        components.day = 1

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return month.monthKey
    }

    // MARK: - Budget Utilization

    private func computeBudgetUtilization() {
        let expenseMappings = columnMappingService.loadDatabaseMappings().values.filter { $0.role == .expense }

        guard !expenseMappings.isEmpty else {
            budgetCategories = []
            budgetSummary = nil
            return
        }

        var dataSourceIds: [String] = []
        var categoryPageById: [String: NotionPage] = [:]
        var pageIdToDbId: [String: String] = [:]

        for mapping in expenseMappings {
            guard let dsId = mapping.columnMapping?.categoryRelationDataSourceId else { continue }
            if !dataSourceIds.contains(dsId) {
                dataSourceIds.append(dsId)
            }
            if let pages = categoryPagesByDataSource[dsId] {
                for page in pages {
                    categoryPageById[page.id] = page
                    pageIdToDbId[page.id] = dsId
                }
            }
        }

        guard !dataSourceIds.isEmpty else {
            budgetCategories = []
            budgetSummary = nil
            return
        }

        var pageBudget: [String: Double] = [:]
        for (pageId, page) in categoryPageById {
            if let budget = detectBudgetProperty(from: page) ?? detectBudgetFromFormulaOrRollup(from: page) {
                pageBudget[pageId] = budget
            }
        }

        let selectedExpenses = selectedMonthExpensesList
        var spentByCategoryId: [String: Double] = [:]

        for expense in selectedExpenses {
            guard let rawProps = expense.rawProperties else { continue }

            for mapping in expenseMappings {
                guard let categoryCol = mapping.columnMapping?.categoryColumn,
                      let dsId = mapping.columnMapping?.categoryRelationDataSourceId,
                      !dsId.isEmpty else { continue }

                if let prop = rawProps[categoryCol], let relations = prop.relation {
                    for relation in relations {
                        if let catId = relation.id {
                            spentByCategoryId[catId, default: 0] += expense.amount
                        }
                    }
                }
            }
        }

        var items: [BudgetCategoryItem] = []

        for (pageId, page) in categoryPageById {
            let name = page.title
            let iconEmoji = page.icon?.emoji
            let spent = spentByCategoryId[pageId] ?? 0
            let budget = pageBudget[pageId]

            let item = BudgetCategoryItem(
                categoryPageId: pageId,
                categoryName: name,
                iconEmoji: iconEmoji,
                spent: spent,
                budget: budget
            )
            items.append(item)
        }

        for (catId, spent) in spentByCategoryId {
            if !categoryPageById.keys.contains(catId) {
                let item = BudgetCategoryItem(
                    categoryPageId: catId,
                    categoryName: "Unknown",
                    iconEmoji: nil,
                    spent: spent,
                    budget: nil
                )
                items.append(item)
            }
        }

        items.sort { a, b in
            let aOrder = a.status.sortOrder
            let bOrder = b.status.sortOrder
            if aOrder != bOrder { return aOrder < bOrder }

            let aPct = a.utilizationPercent ?? -1
            let bPct = b.utilizationPercent ?? -1
            if aPct != bPct { return aPct > bPct }

            if a.spent != b.spent { return a.spent > b.spent }
            return a.categoryName < b.categoryName
        }

        budgetCategories = items

        let budgetedItems = items.filter { $0.budget != nil && $0.budget! > 0 }
        let totalBudget = budgetedItems.reduce(0) { $0 + ($1.budget ?? 0) }
        let totalSpent = budgetedItems.reduce(0) { $0 + $1.spent }
        let overBudgetCount = items.filter { $0.status == .overBudget }.count
        let warningCount = items.filter { $0.status == .warning }.count
        let onTrackCount = items.filter { $0.status == .safe }.count

        budgetSummary = BudgetUtilizationSummary(
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            overBudgetCount: overBudgetCount,
            warningCount: warningCount,
            onTrackCount: onTrackCount
        )
    }

    private func detectBudgetProperty(from page: NotionPage) -> Double? {
        guard let props = page.properties else { return nil }

        var bestScore = -1
        var bestValue: Double?

        let budgetKeywords = ["monthly budget", "budget", "limit", "monthly limit", "planned", "target", "cap"]

        for (name, value) in props {
            guard value.type == "number", let num = value.number else { continue }

            let lowerName = name.lowercased().trimmingCharacters(in: .whitespaces)
            var score = 0

            if lowerName == "monthly budget" { score = 100 }
            else if lowerName == "budget" { score = 90 }
            else if lowerName == "limit" { score = 80 }
            else if lowerName == "monthly limit" { score = 85 }
            else if lowerName == "planned" { score = 70 }
            else if lowerName == "target" { score = 60 }
            else if lowerName == "cap" { score = 50 }
            else {
                for keyword in budgetKeywords {
                    if lowerName.contains(keyword) {
                        score = max(score, 40)
                        break
                    }
                }
            }

            if score > bestScore {
                bestScore = score
                bestValue = num
            }
        }

        return bestValue
    }

    private func detectBudgetFromFormulaOrRollup(from page: NotionPage) -> Double? {
        guard let props = page.properties else { return nil }

        for (name, value) in props {
            if value.type == "formula" || value.type == "rollup" {
                let number = value.number ?? value.rollup?.number
                if let number = number {
                    let lowerName = name.lowercased()
                    if lowerName.contains("budget") || lowerName.contains("limit") {
                        return number
                    }
                }
            }
        }
        return nil
    }

    private func extractTitle(from page: NotionPage) -> String {
        if let props = page.properties {
            for (key, value) in props {
                if let titleArray = value.title, !titleArray.isEmpty {
                    for item in titleArray {
                        if let text = item.text?.content, !text.isEmpty {
                            return text
                        }
                        if let text = item.plainText, !text.isEmpty {
                            return text
                        }
                    }
                }
            }
        }
        return String(page.id.prefix(8))
    }
}

struct DashboardStatusInfo {
    let mainText: String
    let subText: String
    let footerText: String
    let balance: Double
    let hasIncome: Bool
    let hasExpenses: Bool
}
