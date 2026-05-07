//
//  DashboardViewModel.swift
//  Notra
//

import Foundation

protocol DashboardViewModelDelegate: AnyObject {
    func didStartLoading()
    func didFinishLoading(success: Bool, error: Error?)
    func didUpdateProgress(current: Int, total: Int)
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

    private var relationLookupMap: [String: [String: String]] = [:]  // [relationDatabaseId: [pageId: title]]

    var currentMonthExpenses: Double = 0
    var currentMonthIncomes: Double = 0
    var previousMonthExpenses: Double = 0
    var previousMonthIncomes: Double = 0

    var currentMonthExpensesCount: Int = 0
    var currentMonthIncomesCount: Int = 0

    init(token: String) {
        self.token = token
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
            self?.fetchDataForCurrentAndPreviousMonth()
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

    private func fetchDataForCurrentAndPreviousMonth() {
        let calendar = Calendar.current
        let now = Date()

        let currentMonth = MonthMetadata(date: now)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previousMonth = MonthMetadata(date: previousMonthDate)

        SessionCacheManager.shared.setFetchedMonths([currentMonth, previousMonth])

        let totalDatabases = expenseMappings.count + incomeMappings.count
        var completed = 0

        var allExpenses: [NormalizedTransaction] = []
        var allIncomes: [NormalizedTransaction] = []

        let group = DispatchGroup()

        for mapping in expenseMappings {
            group.enter()
            fetchAndNormalize(database: mapping, role: .expense) { expenses in
                allExpenses.append(contentsOf: expenses)
                completed += 1
                self.delegate?.didUpdateProgress(current: completed, total: totalDatabases)
                group.leave()
            }
        }

        for mapping in incomeMappings {
            group.enter()
            fetchAndNormalize(database: mapping, role: .income) { incomes in
                allIncomes.append(contentsOf: incomes)
                completed += 1
                self.delegate?.didUpdateProgress(current: completed, total: totalDatabases)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.processResults(expenses: allExpenses, incomes: allIncomes, currentMonth: currentMonth, previousMonth: previousMonth)
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

    private func processResults(expenses: [NormalizedTransaction], incomes: [NormalizedTransaction], currentMonth: MonthMetadata, previousMonth: MonthMetadata) {
        SessionCacheManager.shared.populateCache(expenses: expenses, incomes: incomes)

        let calendar = Calendar.current

        let currentExpenses = expenses.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == currentMonth.monthKey
        }
        currentMonthExpenses = currentExpenses.reduce(0) { $0 + $1.amount }
        currentMonthExpensesCount = currentExpenses.count

        let previousExpenses = expenses.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == previousMonth.monthKey
        }
        previousMonthExpenses = previousExpenses.reduce(0) { $0 + $1.amount }

        let currentIncomes = incomes.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == currentMonth.monthKey
        }
        currentMonthIncomes = currentIncomes.reduce(0) { $0 + $1.amount }
        currentMonthIncomesCount = currentIncomes.count

        let previousIncomes = incomes.filter { transaction in
            let month = MonthMetadata(date: transaction.date)
            return month.monthKey == previousMonth.monthKey
        }
        previousMonthIncomes = previousIncomes.reduce(0) { $0 + $1.amount }

        print("[DashboardViewModel] Cache retrieval success")
        delegate?.didFinishLoading(success: true, error: nil)
    }

    func getCacheSummary() -> String {
        return SessionCacheManager.shared.getTransactionSummary()
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
