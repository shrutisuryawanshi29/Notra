//
//  NotionService.swift
//  Notra
//

import Foundation

enum NotionError: LocalizedError {
    case invalidToken
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case noPages
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid token. Please check your Notion Integration token."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Notion API."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noPages:
            return "No accessible pages found. Make sure your integration has access to at least one page."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

final class NotionService {
    static let shared = NotionService()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion

    private init() {}

    func fetchTopLevelPages(token: String, completion: @escaping (Result<[NotionPage], NotionError>) -> Void) {
        guard !token.isEmpty else {
            completion(.failure(.invalidToken))
            return
        }

        guard let url = URL(string: baseURL + AppConstants.API.searchEndpoint) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["filter": ["property": "object", "value": "page"]])

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            if httpResponse.statusCode == 401 {
                DispatchQueue.main.async { completion(.failure(.invalidToken)) }
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

                let topLevelPages = searchResponse.results
                    .filter { $0.parent.type == "workspace" && $0.parent.workspace == true }
                    .sorted { $0.title.lowercased() < $1.title.lowercased() }

                DispatchQueue.main.async {
                    if topLevelPages.isEmpty {
                        completion(.failure(.noPages))
                    } else {
                        completion(.success(topLevelPages))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(.decodingError(error))) }
            }
        }.resume()
    }
}