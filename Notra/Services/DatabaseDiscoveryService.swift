//
//  DatabaseDiscoveryService.swift
//  Notra
//

import Foundation

enum DatabaseDiscoveryError: LocalizedError {
    case noToken
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noToken: return "No token found"
        case .networkError(let error): return "Network: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response"
        }
    }
}

final class DatabaseDiscoveryService {
    static let shared = DatabaseDiscoveryService()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion
    private let debug = true

    private init() {}

    func discoverDatabases(from pageId: String, token: String, completion: @escaping (Result<[DiscoveredDatabase], Error>) -> Void) {
        if debug { print("[DatabaseDiscovery] Searching all accessible databases") }

        searchAllDatabases(token: token) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let databases):
                if databases.isEmpty {
                    DispatchQueue.main.async { completion(.success([])) }
                    return
                }
                
                self.fetchDatabaseSchemas(databases: databases, token: token) { databasesWithProps in
                    DispatchQueue.main.async {
                        if self.debug { print("[DatabaseDiscovery] Total: \(databasesWithProps.count)") }
                        SessionCacheManager.shared.saveDiscoveredDatabases(databasesWithProps)
                        completion(.success(databasesWithProps))
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func searchAllDatabases(token: String, completion: @escaping (Result<[DiscoveredDatabase], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/search") else {
            completion(.failure(NSError(domain: "DatabaseDiscovery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "filter": ["property": "object", "value": "database"],
            "sort": ["direction": "ascending", "timestamp": "last_edited_time"]
        ])

        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "DatabaseDiscovery", code: -2, userInfo: [NSLocalizedDescriptionKey: "Parse Error"])))
                return
            }

            var databases: [DiscoveredDatabase] = []
            for item in results {
                guard let id = item["id"] as? String,
                      let titleArray = item["title"] as? [[String: Any]],
                      let first = titleArray.first,
                      let textObj = first["text"] as? [String: Any],
                      let title = textObj["content"] as? String else { continue }
                
                let db = DiscoveredDatabase(id: id, title: title, parentPageId: "", properties: [:], assignedRole: nil)
                databases.append(db)
                if self.debug { print("[DatabaseDiscovery] Found: \(title)") }
            }
            completion(.success(databases))
        }.resume()
    }

    private func fetchDatabaseSchemas(databases: [DiscoveredDatabase], token: String, completion: @escaping ([DiscoveredDatabase]) -> Void) {
        var result = databases
        let group = DispatchGroup()
        
        for (index, db) in databases.enumerated() {
            group.enter()
            guard let url = URL(string: "\(baseURL)/databases/\(db.id)") else {
                group.leave()
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")

            session.dataTask(with: request) { data, _, error in
                defer { group.leave() }
                guard error == nil, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let properties = json["properties"] as? [String: Any] else { return }
                
                var dbProperties: [String: DiscoveredDatabase.DatabaseProperty] = [:]
                for (propName, propValue) in properties {
                    if let prop = propValue as? [String: Any], let propType = prop["type"] as? String {
                        var relationDbId: String? = nil
                        if propType == "relation", let relationConfig = prop["relation"] as? [String: Any] {
                            relationDbId = relationConfig["data_source_id"] as? String
                        }
                        dbProperties[propName] = DiscoveredDatabase.DatabaseProperty(name: propName, type: propType, relationDataSourceId: relationDbId)
                    }
                }
                
                // For title property, add it manually
                if dbProperties.isEmpty || dbProperties["title"] == nil {
                    dbProperties["title"] = DiscoveredDatabase.DatabaseProperty(name: "Title", type: "title")
                }
                
                result[index] = DiscoveredDatabase(
                    id: db.id,
                    title: db.title,
                    parentPageId: db.parentPageId,
                    properties: dbProperties,
                    assignedRole: db.assignedRole
                )
            }.resume()
        }

        group.notify(queue: .main) { completion(result) }
    }
}