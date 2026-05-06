//
//  NotionPage.swift
//  Notra
//

import Foundation

struct NotionPage: Codable {
    let id: String
    let createdTime: String
    let lastEditedTime: String
    let createdBy: NotionUser?
    let lastEditedBy: NotionUser?
    let parent: NotionParent
    let url: String
    let icon: NotionIcon?
    let cover: NotionCover?
    let properties: [String: NotionPropertyValue]?
    let archived: Bool
    let `in`: NotionIn?
    let notionClass: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case parent
        case url
        case icon
        case cover
        case properties
        case archived
        case `in` = "in"
        case notionClass = "object"
    }

    var title: String {
        if let props = properties, let titleProp = props["title"], let titleArray = titleProp.title {
            for item in titleArray {
                if let text = item.text?.content, !text.isEmpty {
                    return text
                }
                if let text = item.plainText, !text.isEmpty {
                    return text
                }
            }
        }
        if let icon = icon, let emoji = icon.emoji {
            return emoji
        }
        return String(id.prefix(8))
    }
}

struct NotionUser: Codable {
    let id: String
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
    }
}

struct NotionIcon: Codable {
    let type: String?
    let emoji: String?
    let file: NotionFile?
    let external: NotionExternal?
}

struct NotionFile: Codable {
    let url: String
    let expiryTime: String?

    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct NotionExternal: Codable {
    let url: String
}

struct NotionCover: Codable {
    let type: String?
    let file: NotionFile?
    let external: NotionExternal?
}

struct NotionProperties: Codable {
    // Dynamic coding - any page properties
    var isEmpty: Bool {
        return true
    }
}

struct NotionIn: Codable {
    let type: String?
}

struct NotionPropertyValue: Codable {
    let type: String?
    let title: [NotionRichText]?
    let richText: [NotionRichText]?
    let number: Double?
    let select: NotionSelect?
    let multiSelect: [NotionSelect]?
    let date: NotionDate?
    let checkbox: Bool?
    let url: String?
    let email: String?
    let phoneNumber: String?
    let people: [NotionPerson]?
    let files: [NotionFileValue]?
    let relation: [NotionRelation]?
    let rollup: NotionRollup?
}

struct NotionSelect: Codable {
    let name: String?
}

struct NotionPerson: Codable {
    let id: String?
    let name: String?
}

struct NotionFileValue: Codable {
    let name: String?
    let file: NotionFile?
    let external: NotionExternal?
}

struct NotionRelation: Codable {
    let id: String?
}

struct NotionRollup: Codable {
    let type: String?
    let number: Double?
    let array: [NotionPropertyValue]?
}

struct NotionDate: Codable {
    let start: String?
    let end: String?
}

struct NotionRichText: Codable {
    let type: String?
    let plainText: String?
    let text: NotionTextContent?
}

struct NotionTextContent: Codable {
    let content: String?
}