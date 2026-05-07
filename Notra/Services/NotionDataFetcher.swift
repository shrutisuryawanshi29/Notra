//
//  NotionDataFetcher.swift
//  Notra
//

import Foundation

final class NotionDataFetcher {
    static let shared = NotionDataFetcher()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion

    private init() {}

    func fetchAllRows(databaseId: String, token: String, completion: @escaping (Result<[NotionPage], NotionError>) -> Void) {
        print("[DataFetcher] fetchAllRows called with ID: \(databaseId)")
        fetchDataSourceRows(dataSourceId: databaseId, token: token, completion: completion)
    }

    func fetchDataSourceRows(dataSourceId: String, token: String, completion: @escaping (Result<[NotionPage], NotionError>) -> Void) {
        print("[DataFetcher] Trying data_source API for ID: \(dataSourceId)")

        guard let url = URL(string: "https://api.notion.com/v1/data_sources/\(dataSourceId)") else {
            print("[DataFetcher] Invalid URL")
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            print("[DataFetcher] Data source API status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200, let data = data else {
                print("[DataFetcher] Data source API failed, trying search approach")
                self.searchAndQueryDataSource(dataSourceId: dataSourceId, token: token, completion: completion)
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(.invalidResponse))
                return
            }

            var databaseId: String?

            if let parent = json["parent"] as? [String: Any], let dbId = parent["database_id"] as? String {
                databaseId = dbId
                print("[DataFetcher] Found database_id in parent: \(dbId)")
            }

            if databaseId == nil, let source = json["source"] as? [String: Any], let dbId = source["database_id"] as? String {
                databaseId = dbId
                print("[DataFetcher] Found database_id in source: \(dbId)")
            }

            guard let finalDbId = databaseId else {
                print("[DataFetcher] No database_id found in response, trying search")
                self.searchAndQueryDataSource(dataSourceId: dataSourceId, token: token, completion: completion)
                return
            }

            print("[DataFetcher] Querying database: \(finalDbId)")
            self.fetchDatabaseRowsDirect(databaseId: finalDbId, token: token, completion: completion)
        }.resume()
    }

    private func searchAndQueryDataSource(dataSourceId: String, token: String, completion: @escaping (Result<[NotionPage], NotionError>) -> Void) {
        print("[DataFetcher] Using search to find data source")

        guard let url = URL(string: baseURL + "/search") else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "filter": ["property": "object", "value": "database"],
            "query": dataSourceId
        ])

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstDb = results.first,
                  let dbId = firstDb["id"] as? String else {
                print("[DataFetcher] Search failed, trying direct query as last resort")
                self.fetchDatabaseRowsDirect(databaseId: dataSourceId, token: token, completion: completion)
                return
            }

            print("[DataFetcher] Found database via search: \(dbId)")
            self.fetchDatabaseRowsDirect(databaseId: dbId, token: token, completion: completion)
        }.resume()
    }

    private func fetchDatabaseRowsDirect(databaseId: String, token: String, completion: @escaping (Result<[NotionPage], NotionError>) -> Void) {
        print("[DataFetcher] Fetching directly from database: \(databaseId)")
        
        guard let url = URL(string: baseURL + "/databases/\(databaseId)/query") else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [:])

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            if httpResponse.statusCode != 200 {
                DispatchQueue.main.async { completion(.failure(.apiError("Status: \(httpResponse.statusCode)"))) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            do {
                let searchResponse = try JSONDecoder().decode(NotionSearchResponse.self, from: data)
                print("[DataFetcher] Successfully fetched \(searchResponse.results.count) rows")
                DispatchQueue.main.async { completion(.success(searchResponse.results)) }
            } catch {
                print("[DataFetcher] Decode error: \(error)")
                DispatchQueue.main.async { completion(.failure(.decodingError(error))) }
            }
        }.resume()
    }
}