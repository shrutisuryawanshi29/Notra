import Foundation
import UIKit

protocol IncomeListViewModelDelegate: AnyObject {
    func didLoadIncomes()
}

final class IncomeListViewModel {
    weak var delegate: IncomeListViewModelDelegate?

    var sections: [GroupedTransactionSection] = []
    var totalAmount: Double = 0

    var activeFilters: [TransactionFilter] = []
    var dateRange: DateRangeFilter?
    var allTransactions: [NormalizedTransaction] = []
    var searchQuery: String = ""

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setSearchQuery(_ query: String) {
        searchQuery = query
        applyCurrentFilters()
    }

    func loadFromCache() {
        allTransactions = SessionCacheManager.shared.allIncomes
        applyCurrentFilters()
        #if DEBUG
        print("[IncomeListViewModel] Loaded from cache: \(allTransactions.count) total transactions")
        #endif
    }

    func applyFilters(filters: [TransactionFilter], dateRange: DateRangeFilter?) {
        self.activeFilters = filters
        self.dateRange = dateRange
        applyCurrentFilters()
    }

    func removeFilter(byId id: UUID) {
        activeFilters.removeAll { $0.id == id }
        applyCurrentFilters()
    }

    func clearDateRange() {
        dateRange = nil
        applyCurrentFilters()
    }

    func clearFilters() {
        activeFilters = []
        dateRange = nil
        applyCurrentFilters()
    }

    var hasActiveFilters: Bool {
        return !activeFilters.isEmpty || (dateRange?.isActive == true)
    }

    var activeFilterCount: Int {
        var count = activeFilters.count
        if dateRange?.isActive == true { count += 1 }
        return count
    }

    var databaseIds: [String] {
        let ids = Set(allTransactions.map { $0.databaseId })
        return Array(ids)
    }

    private func applyCurrentFilters() {
        let filtered = FilterEngine.applyFilters(
            to: allTransactions,
            filters: activeFilters,
            dateRange: dateRange,
            relationLookup: nil
        )
        let searched = applySearch(to: filtered)
        sections = groupTransactionsByDate(searched)
        totalAmount = searched.reduce(0) { $0 + $1.amount }
        delegate?.didLoadIncomes()
    }

    private func applySearch(to transactions: [NormalizedTransaction]) -> [NormalizedTransaction] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return transactions }
        return transactions.filter { LocalSearchService.transactionMatchesSearch($0, query: trimmed) }
    }

    private func groupTransactionsByDate(_ transactions: [NormalizedTransaction]) -> [GroupedTransactionSection] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        var grouped: [String: [NormalizedTransaction]] = [:]

        for transaction in transactions {
            let key = dateFormatter.string(from: transaction.date)
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(transaction)
        }

        var sections: [GroupedTransactionSection] = []

        for (dateKey, txns) in grouped.sorted(by: { $0.key > $1.key }) {
            if let date = dateFormatter.date(from: dateKey) {
                let section = GroupedTransactionSection(
                    date: dateKey,
                    displayDate: displayFormatter.string(from: date),
                    transactions: txns.sorted { $0.amount > $1.amount },
                    totalAmount: txns.reduce(0) { $0 + $1.amount }
                )
                sections.append(section)
            }
        }

        return sections
    }

    func getTransaction(at indexPath: IndexPath) -> NormalizedTransaction? {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].transactions.count else {
            return nil
        }
        return sections[indexPath.section].transactions[indexPath.row]
    }

    var hasData: Bool {
        return !sections.isEmpty
    }
}
