//
//  DynamicFormField.swift
//  Notra
//

import Foundation

struct DynamicFormField: Identifiable {
    let id: String
    let propertyName: String
    let propertyType: NotionPropertyType
    var isRequired: Bool
    var isMappedCoreField: Bool
    var mappedRole: String?
    var options: [SelectOption]
    var relationDataSourceId: String?

    init(
        propertyName: String,
        propertyType: NotionPropertyType,
        isRequired: Bool = false,
        isMappedCoreField: Bool = false,
        mappedRole: String? = nil,
        options: [SelectOption] = [],
        relationDataSourceId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.isRequired = isRequired
        self.isMappedCoreField = isMappedCoreField
        self.mappedRole = mappedRole
        self.options = options
        self.relationDataSourceId = relationDataSourceId
    }

    var displayName: String {
        return propertyName
    }
}

struct SelectOption: Codable, Equatable {
    let name: String
}

struct DynamicFormValue {
    var propertyName: String
    var propertyType: NotionPropertyType

    var stringValue: String?
    var numberValue: Double?
    var boolValue: Bool?
    var dateValue: Date?
    var selectValue: String?
    var multiSelectValues: [String]?
    var relationIds: [String]?

    init(propertyName: String, propertyType: NotionPropertyType) {
        self.propertyName = propertyName
        self.propertyType = propertyType
    }

    init(propertyName: String, propertyType: NotionPropertyType, stringValue: String?) {
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.stringValue = stringValue
    }

    var isEmpty: Bool {
        switch propertyType {
        case .title, .richText, .url, .email, .phoneNumber:
            return stringValue?.isEmpty ?? true
        case .number:
            return numberValue == nil
        case .select:
            return selectValue?.isEmpty ?? true
        case .multiSelect:
            return (multiSelectValues ?? []).isEmpty
        case .date:
            return dateValue == nil
        case .relation:
            return (relationIds ?? []).isEmpty
        case .checkbox:
            return false
        case .status:
            return selectValue?.isEmpty ?? true
        }
    }
}