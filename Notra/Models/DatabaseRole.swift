//
//  DatabaseRole.swift
//  Notra
//

import Foundation

enum DatabaseRole: String, Codable, CaseIterable {
    case expense = "expense"
    case income = "income"
    case ignore = "ignore"

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .ignore: return "Ignore"
        }
    }
}