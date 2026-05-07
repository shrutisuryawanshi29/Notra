//
//  DiscoveredDatabase.swift
//  Notra
//

import Foundation

struct DiscoveredDatabase: Codable, Identifiable {
    let id: String
    let title: String
    let parentPageId: String
    var properties: [String: DatabaseProperty]
    var assignedRole: DatabaseRole?

    struct DatabaseProperty: Codable {
        let name: String
        let type: String
        var relationDataSourceId: String?  // For relation type, stores target data source ID
    }
}

struct AllDatabaseMappings: Codable {
    var mappings: [String: DatabaseMappingData]
}

struct DatabaseMappingData: Codable {
    let databaseId: String
    let databaseTitle: String
    let role: DatabaseRole
    let columnMapping: ColumnMapping?
    let categoryType: String?
    let categoryValuesJSON: String?
}

struct ColumnMapping: Codable {
    var titleColumn: String?
    var amountColumn: String?
    var categoryColumn: String?
    var categoryRelationDataSourceId: String?  // Target data source ID if category is relation
    var dateColumn: String?
}