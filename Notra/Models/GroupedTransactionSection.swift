//
//  GroupedTransactionSection.swift
//  Notra
//

import Foundation

struct GroupedTransactionSection {
    let date: String
    let displayDate: String
    let transactions: [NormalizedTransaction]
    let totalAmount: Double
}

struct NormalizedTransaction: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let category: String?
    let date: Date
    let databaseId: String
    let databaseRole: DatabaseRole

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MonthMetadata: Codable {
    let year: Int
    let month: Int
    let monthKey: String

    init(date: Date) {
        let calendar = Calendar.current
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)
        self.monthKey = String(format: "%04d-%02d", year, month)
    }
}