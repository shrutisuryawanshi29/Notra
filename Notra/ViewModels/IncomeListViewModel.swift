//
//  IncomeListViewModel.swift
//  Notra
//

import Foundation
import UIKit

protocol IncomeListViewModelDelegate: AnyObject {
    func didLoadIncomes()
}

final class IncomeListViewModel {
    weak var delegate: IncomeListViewModelDelegate?

    var sections: [GroupedTransactionSection] = []
    var totalAmount: Double = 0

    func loadFromCache() {
        sections = SessionCacheManager.shared.groupedIncomes
        totalAmount = SessionCacheManager.shared.allIncomes.reduce(0) { $0 + $1.amount }
        print("[IncomeListViewModel] Loaded from cache: \(sections.count) sections")
        delegate?.didLoadIncomes()
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