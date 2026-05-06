//
//  NotionSearchResponse.swift
//  Notra
//

import Foundation

struct NotionSearchResponse: Codable {
    let object: String
    let results: [NotionPage]
    let nextCursor: String?
    let hasMore: Bool
    let type: String?
    let page: NotionPage?

    enum CodingKeys: String, CodingKey {
        case object
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case type
        case page
    }
}