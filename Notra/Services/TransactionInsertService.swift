//
//  TransactionInsertService.swift
//  Notra
//

import Foundation

enum TransactionInsertError: LocalizedError {
    case invalidDatabaseId
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .invalidDatabaseId: return "Invalid database ID"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from Notion API"
        case .apiError(let message): return "API error: \(message)"
        case .missingRequiredField(let name): return "Missing required field: \(name)"
        }
    }
}

final class TransactionInsertService {
    static let shared = TransactionInsertService()

    private let session = URLSession.shared
    private let baseURL = AppConstants.API.notionBaseURL
    private let notionVersion = AppConstants.API.notionVersion

    private init() {}

    func insertTransaction(
        databaseId: String,
        values: [DynamicFormValue],
        token: String,
        completion: @escaping (Result<NotionPage, TransactionInsertError>) -> Void
    ) {
        print("[TransactionInsert] Preparing insert for database: \(databaseId)")
        print("[TransactionInsert] Building property payload with \(values.count) fields")

        let properties = buildPropertyPayload(values: values)

        let parent: [String: Any] = ["database_id": databaseId]

        let payload: [String: Any] = [
            "parent": parent,
            "properties": properties
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(.invalidResponse))
            return
        }

        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[TransactionInsert] Full payload:\n\(jsonString)")
        }

        guard let url = URL(string: baseURL + "/pages") else {
            completion(.failure(.invalidDatabaseId))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[TransactionInsert] Network error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            print("[TransactionInsert] Insert response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                var errorMessage = "Status: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                print("[TransactionInsert] API error: \(errorMessage)")
                DispatchQueue.main.async { completion(.failure(.apiError(errorMessage))) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            do {
                let page = try JSONDecoder().decode(NotionPage.self, from: data)
                print("[TransactionInsert] Successfully created page: \(page.id)")
                DispatchQueue.main.async { completion(.success(page)) }
            } catch {
                print("[TransactionInsert] Decode error: \(error)")
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
        }.resume()
    }

    private func buildPropertyPayload(values: [DynamicFormValue]) -> [String: Any] {
        var properties: [String: Any] = [:]

        for value in values {
            let propName = value.propertyName

            switch value.propertyType {
            case .title:
                if let text = value.stringValue, !text.isEmpty {
                    properties[propName] = [
                        "title": [
                            ["text": ["content": text]]
                        ]
                    ]
                } else {
                    properties[propName] = ["title": []]
                }

            case .richText:
                if let text = value.stringValue, !text.isEmpty {
                    properties[propName] = [
                        "rich_text": [
                            ["text": ["content": text]]
                        ]
                    ]
                } else {
                    properties[propName] = ["rich_text": []]
                }

            case .number:
                if let num = value.numberValue {
                    properties[propName] = ["number": num]
                } else {
                    properties[propName] = ["number": NSNull()]
                }

            case .select:
                if let option = value.selectValue, !option.isEmpty {
                    properties[propName] = ["select": ["name": option]]
                } else {
                    properties[propName] = ["select": NSNull()]
                }

            case .multiSelect:
                let options = value.multiSelectValues ?? []
                properties[propName] = [
                    "multi_select": options.map { ["name": $0] }
                ]

            case .date:
                if let date = value.dateValue {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    properties[propName] = ["date": ["start": formatter.string(from: date)]]
                } else {
                    properties[propName] = ["date": NSNull()]
                }

            case .relation:
                let ids = value.relationIds ?? []
                properties[propName] = [
                    "relation": ids.map { ["id": $0] }
                ]

            case .checkbox:
                properties[propName] = ["checkbox": value.boolValue ?? false]

            case .url:
                if let urlStr = value.stringValue, !urlStr.isEmpty {
                    properties[propName] = ["url": urlStr]
                } else {
                    properties[propName] = ["url": NSNull()]
                }

            case .email:
                if let emailStr = value.stringValue, !emailStr.isEmpty {
                    properties[propName] = ["email": emailStr]
                } else {
                    properties[propName] = ["email": NSNull()]
                }

            case .phoneNumber:
                if let phone = value.stringValue, !phone.isEmpty {
                    properties[propName] = ["phone_number": phone]
                } else {
                    properties[propName] = ["phone_number": NSNull()]
                }

            case .status:
                if let option = value.selectValue, !option.isEmpty {
                    properties[propName] = ["status": ["name": option]]
                } else {
                    properties[propName] = ["status": NSNull()]
                }
            }
        }

        return properties
    }

    private func sortRelationOptions(_ options: [(id: String, title: String)]) -> [(id: String, title: String)] {
        let monthYearPatterns = [
            "^\\w+ \\d{4}$",
            "^\\w+, \\d{4}$",
            "^\\d{4} \\w+$",
            "^\\d{4}-\\d{2}$",
            "^\\d{2}/\\d{4}$"
        ]

        let allMatchMonthYear = options.allSatisfy { option in
            monthYearPatterns.contains { pattern in
                option.title.range(of: pattern, options: .regularExpression) != nil
            }
        }

        if allMatchMonthYear && !options.isEmpty {
            let monthOrder = ["January", "February", "March", "April", "May", "June",
                              "July", "August", "September", "October", "November", "December"]
            let shortMonthOrder = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

            let sorted = options.sorted { a, b in
                let titleA = a.title
                let titleB = b.title

                let dateA = parseMonthYear(titleA, fullOrder: monthOrder, shortOrder: shortMonthOrder)
                let dateB = parseMonthYear(titleB, fullOrder: monthOrder, shortOrder: shortMonthOrder)

                if let dA = dateA, let dB = dateB {
                    return dA > dB
                }
                return titleA < titleB
            }
            return sorted
        }

        return options.sorted { $0.title < $1.title }
    }

    private func isIdLike(_ title: String) -> Bool {
        let len = title.count
        guard len >= 8 && len <= 12 else { return false }
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return title.unicodeScalars.allSatisfy { hex.contains($0) }
    }

    private func parseMonthYear(_ title: String, fullOrder: [String], shortOrder: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")

        let formats = [
            "MMMM yyyy",
            "MMM yyyy",
            "MMMM, yyyy",
            "yyyy MMMM",
            "yyyy-MM",
            "MM/yyyy"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: title) {
                return date
            }
        }

        let yearPattern = "(\\d{4})"
        let monthFullPattern = "(January|February|March|April|May|June|July|August|September|October|November|December)"
        let monthShortPattern = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"

        if let yearMatch = title.range(of: yearPattern, options: .regularExpression) {
            let yearStr = String(title[yearMatch])
            if let year = Int(yearStr) {
                if let monthMatch = title.range(of: monthFullPattern, options: .caseInsensitive) {
                    let monthStr = String(title[monthMatch])
                    if let monthIdx = fullOrder.firstIndex(of: monthStr) {
                        return Calendar.current.date(from: DateComponents(year: year, month: monthIdx + 1))
                    }
                }
                if let monthMatch = title.range(of: monthShortPattern, options: .caseInsensitive) {
                    let monthStr = String(title[monthMatch])
                    if let monthIdx = shortOrder.firstIndex(of: monthStr) {
                        return Calendar.current.date(from: DateComponents(year: year, month: monthIdx + 1))
                    }
                }
            }
        }

        return nil
    }

    func loadRelationOptions(databaseId: String, token: String, completion: @escaping (Result<[(id: String, title: String)], TransactionInsertError>) -> Void) {
        print("[TransactionInsert] Loading relation options for database: \(databaseId)")

        if let cached = SessionCacheManager.shared.getRelationTargetData(databaseId: databaseId) {
            let options = sortRelationOptions(cached.map { (id: $0.key, title: $0.value) })
            print("[TransactionInsert] Cache HIT (relationData) for \(databaseId): \(options.count) items")
            if let first = options.first, isIdLike(first.title) {
                print("[TransactionInsert] Cache has corrupt titles (stale data from before title fix), re-fetching from API")
                SessionCacheManager.shared.deleteRelationTargetData(databaseId: databaseId)
            } else {
                completion(.success(options))
                return
            }
        }

        if let categoryLookup = SessionCacheManager.shared.getCategoryLookup(for: databaseId) {
            let options = sortRelationOptions(categoryLookup.map { (id: $0.key, title: $0.value) })
            print("[TransactionInsert] Cache HIT (categoryLookup) for \(databaseId): \(options.count) items")
            if let first = options.first, isIdLike(first.title) {
                print("[TransactionInsert] categoryLookup also has corrupt titles, clearing")
                SessionCacheManager.shared.clearCategoryLookup(for: databaseId)
            } else {
                completion(.success(options))
                return
            }
        }

        print("[TransactionInsert] Cache MISS for \(databaseId), calling API")

        guard let url = URL(string: baseURL + "/databases/\(databaseId)/query") else {
            completion(.failure(.invalidResponse))
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
                print("[TransactionInsert] Network error loading relation options: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            print("[TransactionInsert] Relation API status: \(httpResponse.statusCode)")

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
                let options = self.sortRelationOptions(searchResponse.results.map { (id: $0.id, title: $0.title) })
                print("[TransactionInsert] API returned \(options.count) relation options: \(options.map { $0.title }.joined(separator: ", "))")

                SessionCacheManager.shared.saveRelationTargetData(databaseId: databaseId, rows: searchResponse.results)
                DispatchQueue.main.async { completion(.success(options)) }
            } catch {
                print("[TransactionInsert] Decode error loading relation options: \(error)")
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
        }.resume()
    }

    func updateTransaction(
        pageId: String,
        values: [DynamicFormValue],
        token: String,
        completion: @escaping (Result<NotionPage, TransactionInsertError>) -> Void
    ) {
        print("[TransactionInsert] Updating page: \(pageId)")
        print("[TransactionInsert] Building property payload with \(values.count) fields")

        let properties = buildPropertyPayload(values: values)
        let payload: [String: Any] = ["properties": properties]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(.invalidResponse))
            return
        }

        guard let url = URL(string: baseURL + "/pages/\(pageId)") else {
            completion(.failure(.invalidDatabaseId))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[TransactionInsert] Network error updating: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            print("[TransactionInsert] Update response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                var errorMessage = "Status: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                print("[TransactionInsert] API error: \(errorMessage)")
                DispatchQueue.main.async { completion(.failure(.apiError(errorMessage))) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }

            do {
                let page = try JSONDecoder().decode(NotionPage.self, from: data)
                print("[TransactionInsert] Successfully updated page: \(page.id)")
                DispatchQueue.main.async { completion(.success(page)) }
            } catch {
                print("[TransactionInsert] Decode error: \(error)")
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
        }.resume()
    }
}