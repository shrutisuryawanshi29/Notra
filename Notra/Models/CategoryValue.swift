//
//  CategoryValue.swift
//  Notra
//

import Foundation

struct CategoryValue: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sourceType: String

    init(id: String, name: String, sourceType: String) {
        self.id = id
        self.name = name
        self.sourceType = sourceType
    }
}

struct AllCategoryValues: Codable {
    var categories: [String: [CategoryValue]]
}