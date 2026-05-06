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
        var relationDatabaseIds: Set<String> = []

        for mapping in expenseMappings {
            if let relationDbId = mapping.columnMapping?.categoryRelationDatabaseId {
                relationDatabaseIds.insert(relationDbId)
            }
        }

        for mapping in incomeMappings {
            if let relationDbId = mapping.columnMapping?.categoryRelationDatabaseId {
                relationDatabaseIds.insert(relationDbId)
            }
        }

        if relationDatabaseIds.isEmpty {
            print("[DashboardViewModel] No relation target databases found")
            completion()
            return
        }

        print("[DashboardViewModel] Fetching \(relationDatabaseIds.count) relation target databases")

        let group = DispatchGroup()

        for dbId in relationDatabaseIds {
            group.enter()
            dataFetcher.fetchAllRows(databaseId: dbId, token: token) { [weak self] result in
                defer { group.leave() }

                if case .success(let rows) = result {
                    var lookup: [String: String] = [:]
                    for row in rows {
                        let title = row.title.isEmpty ? String(row.id.prefix(8)) : row.title
                        lookup[row.id] = title
                    }
                    self?.relationLookupMap[dbId] = lookup
                    print("[DashboardViewModel] Cached \(lookup.count) items for relation DB: \(dbId)")
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
}