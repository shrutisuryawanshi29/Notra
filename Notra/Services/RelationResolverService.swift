//
//  RelationResolverService.swift
//  Notra
//

import Foundation

final class RelationResolverService {
    static let shared = RelationResolverService()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion

    private init() {}

    func resolveRelationTitles(pageIds: [String], token: String, completion: @escaping (Result<[String], Error>) -> Void) {
        guard !pageIds.isEmpty else {
            completion(.success([]))
            return
        }

        var resolvedTitles: [String] = []
        let group = DispatchGroup()
        let lock = NSLock()

        for pageId in pageIds {
            group.enter()
            fetchPageTitle(pageId: pageId, token: token) { result in
                defer { group.leave() }
                if case .success(let title) = result {
                    lock.lock()
                    resolvedTitles.append(title)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            completion(.success(resolvedTitles.sorted()))
        }
    }

    private func fetchPageTitle(pageId: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pages/\(pageId)") else {
            completion(.failure(NSError(domain: "RelationResolver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let properties = json["properties"] as? [String: Any] else {
                completion(.success("Unknown"))
                return
            }

            for (_, value) in properties {
                guard let prop = value as? [String: Any],
                      let type = prop["type"] as? String,
                      type == "title",
                      let titleArray = prop["title"] as? [[String: Any]],
                      let first = titleArray.first,
                      let textObj = first["text"] as? [String: Any],
                      let content = textObj["content"] as? String else {
                    continue
                }
                completion(.success(content))
                return
            }

            completion(.success("Untitled"))
        }.resume()
    }
}