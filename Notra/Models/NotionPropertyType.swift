//
//  NotionPropertyType.swift
//  Notra
//

import Foundation

enum NotionPropertyType: String, CaseIterable {
    case title
    case richText = "rich_text"
    case number
    case select
    case multiSelect = "multi_select"
    case date
    case relation
    case checkbox
    case url
    case email
    case phoneNumber = "phone_number"
    case status

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .richText: return "Text"
        case .number: return "Number"
        case .select: return "Select"
        case .multiSelect: return "Multi-Select"
        case .date: return "Date"
        case .relation: return "Relation"
        case .checkbox: return "Checkbox"
        case .url: return "URL"
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .status: return "Status"
        }
    }

    static func from(string: String) -> NotionPropertyType? {
        return NotionPropertyType(rawValue: string)
    }

    var isWritable: Bool {
        switch self {
        case .title, .richText, .number, .select, .multiSelect, .date, .relation, .checkbox, .url, .email, .phoneNumber, .status:
            return true
        }
    }

    static var readOnlyTypes: Set<String> {
        return ["formula", "rollup", "created_time", "created_by", "last_edited_time", "last_edited_by", "unique_id", "verification"]
    }

    static func isReadOnly(_ type: String) -> Bool {
        return readOnlyTypes.contains(type)
    }
}