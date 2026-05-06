//
//  ExpenseListViewModel.swift
//  Notra
//

import Foundation
import UIKit

protocol ExpenseListViewModelDelegate: AnyObject {
    func didLoadExpenses()
}

final class ExpenseListViewModel {
    weak var delegate: ExpenseListViewModelDelegate?

    var sections: [GroupedTransactionSection] = []
    var totalAmount: Double = 0

    func loadFromCache() {
        sections = SessionCacheManager.shared.groupedExpenses
        totalAmount = SessionCacheManager.shared.allExpenses.reduce(0) { $0 + $1.amount }
        print("[ExpenseListViewModel] Loaded from cache: \(sections.count) sections")
        delegate?.didLoadExpenses()
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