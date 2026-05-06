//
//  CategoryParserService.swift
//  Notra
//

import Foundation

final class CategoryParserService {
    static let shared = CategoryParserService()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion

    private init() {}

    func parseCategories(databaseId: String, categoryPropertyName: String, databaseSchema: [String: Any], token: String, completion: @escaping (Result<[CategoryValue], Error>) -> Void) {
        fetchDatabaseRows(databaseId: databaseId, token: token) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let rows):
                let categories = self.extractCategoryValues(from: rows, propertyName: categoryPropertyName, propertyType: databaseSchema[categoryPropertyName] as? String ?? "", token: token)
                DispatchQueue.main.async {
                    completion(.success(categories))
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchDatabaseRows(databaseId: String, token: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/databases/\(databaseId)/query") else {
            completion(.failure(NSError(domain: "CategoryParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["page_size": 100])

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "CategoryParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                return
            }

            completion(.success(results))
        }.resume()
    }

    private func extractCategoryValues(from rows: [[String: Any]], propertyName: String, propertyType: String, token: String) -> [CategoryValue] {
        var categories: [CategoryValue] = []
        var seenIds = Set<String>()

        for row in rows {
            guard let properties = row["properties"] as? [String: Any],
                  let prop = properties[propertyName] as? [String: Any] else {
                continue
            }

            switch propertyType {
            case "select":
                if let select = prop["select"] as? [String: Any],
                   let name = select["name"] as? String,
                   let id = select["id"] as? String,
                   !seenIds.contains(id) {
                    seenIds.insert(id)
                    categories.append(CategoryValue(id: id, name: name, sourceType: "select"))
                }

            case "multi_select":
                if let multiSelect = prop["multi_select"] as? [[String: Any]] {
                    for item in multiSelect {
                        if let id = item["id"] as? String,
                           let name = item["name"] as? String,
                           !seenIds.contains(id) {
                            seenIds.insert(id)
                            categories.append(CategoryValue(id: id, name: name, sourceType: "multi_select"))
                        }
                    }
                }

            case "relation":
                if let relation = prop["relation"] as? [[String: Any]] {
                    let pageIds = relation.compactMap { ($0["id"] as? String) }
                    RelationResolverService.shared.resolveRelationTitles(pageIds: pageIds, token: token) { _ in }

                    for pageId in pageIds {
                        if !seenIds.contains(pageId) {
                            seenIds.insert(pageId)
                            categories.append(CategoryValue(id: pageId, name: "Loading...", sourceType: "relation"))
                        }
                    }
                }

            case "title":
                if let textArray = prop["title"] as? [[String: Any]] {
                    for item in textArray {
                        if let textObj = item["text"] as? [String: Any],
                           let content = textObj["content"] as? String,
                           !seenIds.contains(content) {
                            seenIds.insert(content)
                            categories.append(CategoryValue(id: content, name: content, sourceType: propertyType))
                        }
                    }
                }

            case "rich_text":
                if let textArray = prop["rich_text"] as? [[String: Any]] {
                    for item in textArray {
                        if let textObj = item["text"] as? [String: Any],
                           let content = textObj["content"] as? String,
                           !seenIds.contains(content) {
                            seenIds.insert(content)
                            categories.append(CategoryValue(id: content, name: content, sourceType: propertyType))
                        }
                    }
                }

            default:
                break
            }
        }

        return categories.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}