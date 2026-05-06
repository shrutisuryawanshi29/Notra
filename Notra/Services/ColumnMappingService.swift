//
//  ColumnMappingService.swift
//  Notra
//

import Foundation

final class ColumnMappingService {
    static let shared = ColumnMappingService()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Database Mappings

    func saveDatabaseMappings(_ mappings: [String: DatabaseMappingData]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(mappings) {
            defaults.set(data, forKey: AppConstants.UserDefaultsKeys.databaseMappings)
            SessionCacheManager.shared.databaseMappings = mappings
        }
    }

    func loadDatabaseMappings() -> [String: DatabaseMappingData] {
        if SessionCacheManager.shared.hasSetupComplete {
            return SessionCacheManager.shared.databaseMappings
        }
        
        guard let data = defaults.data(forKey: AppConstants.UserDefaultsKeys.databaseMappings),
              let mappings = try? JSONDecoder().decode([String: DatabaseMappingData].self, from: data) else {
            return [:]
        }
        return mappings
    }

    // MARK: - Column Mappings

    func saveColumnMapping(for databaseId: String, mapping: ColumnMapping) {
        var allMappings = loadDatabaseMappings()
        if let existing = allMappings[databaseId] {
            let updated = DatabaseMappingData(
                databaseId: existing.databaseId,
                databaseTitle: existing.databaseTitle,
                role: existing.role,
                columnMapping: mapping,
                categoryType: existing.categoryType,
                categoryValuesJSON: existing.categoryValuesJSON)
            allMappings[databaseId] = updated
            SessionCacheManager.shared.setMapping(for: databaseId, data: updated)
        }
        saveDatabaseMappings(allMappings)
    }

    // MARK: - Category Values

    func saveCategoryValues(_ categories: [CategoryValue], for databaseId: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(categories) {
            defaults.set(data, forKey: "\(AppConstants.UserDefaultsKeys.categoryValues)_\(databaseId)")
            SessionCacheManager.shared.setCategories(categories, for: databaseId)
        }
    }

    func loadCategoryValues(for databaseId: String) -> [CategoryValue] {
        let cached = SessionCacheManager.shared.getCategories(for: databaseId)
        if !cached.isEmpty {
            return cached
        }
        
        guard let data = defaults.data(forKey: "\(AppConstants.UserDefaultsKeys.categoryValues)_\(databaseId)"),
              let categories = try? JSONDecoder().decode([CategoryValue].self, from: data) else {
            return []
        }
        return categories
    }

    // MARK: - Auto-suggest

    func autoSuggestMapping(for properties: [String: String]) -> ColumnMapping {
        var mapping = ColumnMapping(titleColumn: nil, amountColumn: nil, categoryColumn: nil, dateColumn: nil)

        for (columnName, propertyType) in properties {
            let lowerName = columnName.lowercased()

            if mapping.titleColumn == nil && (propertyType == "title" || propertyType == "rich_text") {
                mapping.titleColumn = columnName
            }

            if mapping.amountColumn == nil && (lowerName.contains("amount") || lowerName.contains("total") || lowerName.contains("price") || lowerName.contains("cost") || propertyType == "number") {
                mapping.amountColumn = columnName
            }

            if mapping.categoryColumn == nil && (lowerName.contains("category") || lowerName.contains("type") || lowerName.contains("expense") || lowerName.contains("source")) {
                mapping.categoryColumn = columnName
            }

            if mapping.dateColumn == nil && (lowerName.contains("date") || lowerName.contains("created") || lowerName.contains("purchase") || lowerName.contains("time") || propertyType == "date") {
                mapping.dateColumn = columnName
            }
        }

        return mapping
    }

    // MARK: - Clear

    func clearAllMappings() {
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.databaseMappings)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.columnMappings)
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(AppConstants.UserDefaultsKeys.categoryValues) }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        SessionCacheManager.shared.clearSession()
    }

    // MARK: - Session Summary

    func getSessionSummary() -> String {
        return SessionCacheManager.shared.setupSummary
    }
}