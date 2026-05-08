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

    private var allExpenses: [NormalizedTransaction] = []
    private var allIncomes: [NormalizedTransaction] = []

    var selectedMonth: MonthMetadata {
        didSet {
            updateSelectedMonthTotals()
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

    var availableMonths: [MonthMetadata] = []

    init(token: String) {
        self.token = token
        self.selectedMonth = MonthMetadata(date: Date())
    }

    func loadData() {
        delegate?.didStartLoading()

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
                        var lookup: [String: String] = [:]
                        for page in pages {
                            let extractedTitle = self?.extractTitle(from: page) ?? String(page.id.prefix(8))
                            print("[DashboardViewModel] Page ID: \(page.id), Extracted title: \(extractedTitle)")
                            lookup[page.id] = extractedTitle
                        }
                        self?.relationLookupMap[dsId] = lookup
                        SessionCacheManager.shared.setCategoryLookup(for: dsId, lookup: lookup)
                        print("[DashboardViewModel] Fetched and cached \(lookup.count) items for data source: \(dsId)")
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
                self.allExpenses.append(contentsOf: expenses)
                completed += 1
                self.delegate?.didUpdateProgress(current: completed, total: totalDatabases)
                group.leave()
            }
        }

        for mapping in incomeMappings {
            group.enter()
            fetchAndNormalize(database: mapping, role: .income) { incomes in
                self.allIncomes.append(contentsOf: incomes)
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

        updateAvailableMonths()
        updateSelectedMonthTotals()

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
