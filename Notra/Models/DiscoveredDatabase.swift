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
    var expenseAppMetadataProperty: String?

    enum CodingKeys: String, CodingKey {
        case titleColumn, amountColumn, categoryColumn, categoryRelationDataSourceId, dateColumn
        case expenseAppMetadataProperty
        case expenseSplitDetailsProperty
    }

    init(titleColumn: String? = nil, amountColumn: String? = nil, categoryColumn: String? = nil, categoryRelationDataSourceId: String? = nil, dateColumn: String? = nil, expenseAppMetadataProperty: String? = nil) {
        self.titleColumn = titleColumn
        self.amountColumn = amountColumn
        self.categoryColumn = categoryColumn
        self.categoryRelationDataSourceId = categoryRelationDataSourceId
        self.dateColumn = dateColumn
        self.expenseAppMetadataProperty = expenseAppMetadataProperty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        titleColumn = try container.decodeIfPresent(String.self, forKey: .titleColumn)
        amountColumn = try container.decodeIfPresent(String.self, forKey: .amountColumn)
        categoryColumn = try container.decodeIfPresent(String.self, forKey: .categoryColumn)
        categoryRelationDataSourceId = try container.decodeIfPresent(String.self, forKey: .categoryRelationDataSourceId)
        dateColumn = try container.decodeIfPresent(String.self, forKey: .dateColumn)
        expenseAppMetadataProperty = try container.decodeIfPresent(String.self, forKey: .expenseAppMetadataProperty)
        if expenseAppMetadataProperty == nil {
            expenseAppMetadataProperty = try container.decodeIfPresent(String.self, forKey: .expenseSplitDetailsProperty)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(titleColumn, forKey: .titleColumn)
        try container.encodeIfPresent(amountColumn, forKey: .amountColumn)
        try container.encodeIfPresent(categoryColumn, forKey: .categoryColumn)
        try container.encodeIfPresent(categoryRelationDataSourceId, forKey: .categoryRelationDataSourceId)
        try container.encodeIfPresent(dateColumn, forKey: .dateColumn)
        try container.encodeIfPresent(expenseAppMetadataProperty, forKey: .expenseAppMetadataProperty)
    }
}