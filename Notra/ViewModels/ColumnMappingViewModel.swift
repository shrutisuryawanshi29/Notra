//
//  ColumnMappingViewModel.swift
//  Notra
//

import Foundation

enum ColumnField: String, CaseIterable {
    case title = "Title"
    case amount = "Amount"
    case category = "Category"
    case date = "Date"

    var placeholder: String {
        switch self {
        case .title: return "Select title column"
        case .amount: return "Select amount column"
        case .category: return "Select category column"
        case .date: return "Select date column"
        }
    }
}

protocol ColumnMappingViewModelDelegate: AnyObject {
    func columnMappingDidStartLoading()
    func columnMappingDidFinishLoading(mapping: ColumnMapping, categories: [CategoryValue])
    func columnMappingDidFail(_ error: String)
}

final class ColumnMappingViewModel {
    weak var delegate: ColumnMappingViewModelDelegate?

    let database: DiscoveredDatabase
    let role: DatabaseRole

    private(set) var columnMapping: ColumnMapping
    private(set) var categoryPropertyType: String = ""
    private(set) var categories: [CategoryValue] = []

    var propertyNames: [String] {
        if database.properties.isEmpty { return [] }
        return Array(database.properties.keys).sorted()
    }

    init(database: DiscoveredDatabase, role: DatabaseRole) {
        self.database = database
        self.role = role
        self.columnMapping = ColumnMapping(titleColumn: nil, amountColumn: nil, categoryColumn: nil, dateColumn: nil)
    }

    func autoSuggestMapping() {
        let propertyTypes = database.properties.reduce(into: [String: String]()) { result, prop in
            result[prop.key] = prop.value.type
        }
        columnMapping = ColumnMappingService.shared.autoSuggestMapping(for: propertyTypes)
    }

    func setMapping(for field: ColumnField, columnName: String?) {
        switch field {
        case .title:
            columnMapping.titleColumn = columnName
        case .amount:
            columnMapping.amountColumn = columnName
        case .category:
            columnMapping.categoryColumn = columnName
        case .date:
            columnMapping.dateColumn = columnName
        }
    }

    func getMapping(for field: ColumnField) -> String? {
        switch field {
        case .title: return columnMapping.titleColumn
        case .amount: return columnMapping.amountColumn
        case .category: return columnMapping.categoryColumn
        case .date: return columnMapping.dateColumn
        }
    }

    func saveAndParseCategories() {
        guard let token = UserDefaultsManager.shared.notionToken else {
            delegate?.columnMappingDidFail("No token")
            return
        }

        delegate?.columnMappingDidStartLoading()

        ColumnMappingService.shared.saveColumnMapping(for: database.id, mapping: columnMapping)

        guard let categoryColumn = columnMapping.categoryColumn else {
            delegate?.columnMappingDidFinishLoading(mapping: columnMapping, categories: [])
            return
        }

        let propertyType = database.properties[categoryColumn]?.type ?? ""

        CategoryParserService.shared.parseCategories(
            databaseId: database.id,
            categoryPropertyName: categoryColumn,
            databaseSchema: database.properties,
            token: token
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let cats):
                self.categories = cats
                self.categoryPropertyType = propertyType
                ColumnMappingService.shared.saveCategoryValues(cats, for: self.database.id)
                DispatchQueue.main.async {
                    self.delegate?.columnMappingDidFinishLoading(mapping: self.columnMapping, categories: cats)
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self.delegate?.columnMappingDidFail(error.localizedDescription)
                }
            }
        }
    }
}