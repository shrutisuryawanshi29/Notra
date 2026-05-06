//
//  NotionParent.swift
//  Notra
//

import Foundation

struct NotionParent: Codable {
    let type: String
    let workspace: Bool?
    let pageId: String?
    let databaseId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case workspace
        case pageId = "page_id"
        case databaseId = "database_id"
    }
}