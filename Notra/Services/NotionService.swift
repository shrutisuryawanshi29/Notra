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

        let urlString = baseURL + AppConstants.API.searchEndpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "filter": [
                "property": "object",
                "value": "page"
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }

        if AppConstants.Debug.enabled {
            print("[NotionService] API request started - fetching pages")
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                if AppConstants.Debug.enabled {
                    print("[NotionService] Network error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode == 401 {
                if AppConstants.Debug.enabled {
                    print("[NotionService] Invalid token - 401 status")
                }
                DispatchQueue.main.async {
                    completion(.failure(.invalidToken))
                }
                return
            }

            if httpResponse.statusCode != 200 {
                let message = "Status code: \(httpResponse.statusCode)"
                if AppConstants.Debug.enabled {
                    print("[NotionService] API error: \(message)")
                }
                DispatchQueue.main.async {
                    completion(.failure(.apiError(message)))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

do {
                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(NotionSearchResponse.self, from: data)

                if AppConstants.Debug.enabled {
                    print("[NotionService] Total results: \(searchResponse.results.count)")
                }

let topLevelPages = searchResponse.results.filter { page in
                    return page.parent.type == "workspace" && page.parent.workspace == true
                }.sorted { $0.title.lowercased() < $1.title.lowercased() }

                if AppConstants.Debug.enabled {
                    print("[NotionService] Top-level pages after filtering: \(topLevelPages.count)")
                }

                DispatchQueue.main.async {
                    if topLevelPages.isEmpty {
                        completion(.failure(.noPages))
                    } else {
                        completion(.success(topLevelPages))
                    }
                }
            } catch {
                if AppConstants.Debug.enabled {
                    print("[NotionService] Decoding error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(error)))
                }
            }
        }

        task.resume()
    }
}
