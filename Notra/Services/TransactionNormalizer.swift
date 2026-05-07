//
//  TransactionNormalizer.swift
//  Notra
//

import Foundation

final class TransactionNormalizer {
    static let shared = TransactionNormalizer()

    private var token: String = ""
    private var relationLookupMap: [String: [String: String]] = [:]  // [relationDbId: [pageId: title]]

    private init() {}

    func setToken(_ token: String) {
        self.token = token
    }

    func setRelationLookupMap(_ map: [String: [String: String]]) {
        self.relationLookupMap = map
    }

    func normalize(rows: [NotionPage], mapping: DatabaseMappingData, role: DatabaseRole, completion: @escaping ([NormalizedTransaction]) -> Void) {
        guard let columnMapping = mapping.columnMapping else {
            print("[DEBUG] No column mapping found for database: \(mapping.databaseId)")
            completion([])
            return
        }

        print("[DEBUG] Normalizing \(rows.count) rows, mapping: title=\(columnMapping.titleColumn ?? "nil"), amount=\(columnMapping.amountColumn ?? "nil"), category=\(columnMapping.categoryColumn ?? "nil"), date=\(columnMapping.dateColumn ?? "nil")")

        var transactions: [NormalizedTransaction] = []
        let group = DispatchGroup()
        var mutex = NSLock()

        for row in rows {
            guard let title = extractTitle(from: row, column: columnMapping.titleColumn) else { continue }

            let amount = extractAmount(from: row, column: columnMapping.amountColumn) ?? 0
            let date = extractDate(from: row, column: columnMapping.dateColumn) ?? Date()

            let prop = row.properties?[columnMapping.categoryColumn ?? ""]
            let isRelation = prop?.type == "relation"

            if isRelation, let relation = prop?.relation, !relation.isEmpty {
                let relationIds = relation.compactMap { $0.id }
                let relationDbId = columnMapping.categoryRelationDataSourceId ?? ""

                print("[DEBUG] Relation: IDs=\(relationIds), targetDb=\(relationDbId)")
                print("[DEBUG] Relation lookup map has \(relationLookupMap.count) databases")

                var categoryNames: [String] = []
                if let dbLookup = relationLookupMap[relationDbId] {
                    print("[DEBUG] Found lookup for DB \(relationDbId) with \(dbLookup.count) items")
                    for relationId in relationIds {
                        if let name = dbLookup[relationId] {
                            print("[DEBUG] Found category: \(name) for ID: \(relationId)")
                            categoryNames.append(name)
                        }
                    }
                } else {
                    print("[DEBUG] NO lookup found for DB: \(relationDbId)")
                }

                let category = categoryNames.isEmpty ? nil : categoryNames.joined(separator: ", ")
                print("[DEBUG] Row: title=\(title), amount=\(amount), category=\(category ?? "NIL"), date=\(date)")

                let transaction = NormalizedTransaction(
                    id: row.id,
                    title: title,
                    amount: abs(amount),
                    category: category,
                    date: date,
                    databaseId: mapping.databaseId,
                    databaseRole: role
                )

                mutex.lock()
                transactions.append(transaction)
                mutex.unlock()
            } else {
                let category = extractCategory(from: row, column: columnMapping.categoryColumn, mapping: mapping)
                print("[DEBUG] Row: title=\(title), amount=\(amount), category=\(category ?? "NIL"), date=\(date)")

                let transaction = NormalizedTransaction(
                    id: row.id,
                    title: title,
                    amount: abs(amount),
                    category: category,
                    date: date,
                    databaseId: mapping.databaseId,
                    databaseRole: role
                )

                mutex.lock()
                transactions.append(transaction)
                mutex.unlock()
            }
        }

        group.notify(queue: .main) {
            completion(transactions)
        }
    }

    func normalize(rows: [NotionPage], mapping: DatabaseMappingData, role: DatabaseRole) -> [NormalizedTransaction] {
        guard let columnMapping = mapping.columnMapping else {
            print("[DEBUG] No column mapping found for database: \(mapping.databaseId)")
            return []
        }

        print("[DEBUG] Normalizing \(rows.count) rows, mapping: title=\(columnMapping.titleColumn ?? "nil"), amount=\(columnMapping.amountColumn ?? "nil"), category=\(columnMapping.categoryColumn ?? "nil"), date=\(columnMapping.dateColumn ?? "nil")")

        var transactions: [NormalizedTransaction] = []

        for row in rows {
            guard let title = extractTitle(from: row, column: columnMapping.titleColumn) else { continue }

            let amount = extractAmount(from: row, column: columnMapping.amountColumn) ?? 0
            let category = extractCategory(from: row, column: columnMapping.categoryColumn, mapping: mapping)
            let date = extractDate(from: row, column: columnMapping.dateColumn) ?? Date()

            print("[DEBUG] Row: title=\(title), amount=\(amount), category=\(category ?? "NIL"), date=\(date)")

            let transaction = NormalizedTransaction(
                id: row.id,
                title: title,
                amount: abs(amount),
                category: category,
                date: date,
                databaseId: mapping.databaseId,
                databaseRole: role
            )
            transactions.append(transaction)
        }

        return transactions
    }

    private func extractTitle(from row: NotionPage, column: String?) -> String? {
        guard let column = column, let props = row.properties else { return nil }

        if let prop = props[column], let titleArray = prop.title {
            for item in titleArray {
                if let text = item.plainText, !text.isEmpty {
                    return text
                }
                if let text = item.text?.content, !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private func extractAmount(from row: NotionPage, column: String?) -> Double? {
        guard let column = column, let props = row.properties else { return nil }

        if let prop = props[column], let numberValue = prop.number {
            return numberValue
        }

        if let prop = props[column], let richText = prop.richText {
            for item in richText {
                if let text = item.plainText ?? item.text?.content {
                    let cleaned = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    if let value = Double(cleaned), value > 0 {
                        return value
                    }
                }
            }
        }

        return nil
    }

    private func extractCategory(from row: NotionPage, column: String?, mapping: DatabaseMappingData) -> String? {
        guard let column = column else {
            print("[DEBUG] Category column is nil")
            return nil
        }

        guard let props = row.properties else {
            print("[DEBUG] Row properties is nil")
            return nil
        }

        guard let prop = props[column] else {
            print("[DEBUG] Property '\(column)' not found in row properties")
            return nil
        }

        print("[DEBUG] Found property for category, type: \(prop.type ?? "unknown"), select: \(prop.select?.name ?? "nil"), multiSelect: \(prop.multiSelect?.count ?? 0), richText: \(prop.richText?.count ?? 0), title: \(prop.title?.count ?? 0)")

        if let select = prop.select, let name = select.name, !name.isEmpty {
            print("[DEBUG] Category from select: \(name)")
            return name
        }

        if let multiSelect = prop.multiSelect, !multiSelect.isEmpty {
            let names = multiSelect.compactMap { $0.name }
            print("[DEBUG] Category from multiSelect: \(names)")
            return names.joined(separator: ", ")
        }

        if let title = prop.title, !title.isEmpty {
            for item in title {
                if let text = item.plainText ?? item.text?.content, !text.isEmpty {
                    print("[DEBUG] Category from title: \(text)")
                    return text
                }
            }
        }

        if let richText = prop.richText, !richText.isEmpty {
            for item in richText {
                if let text = item.plainText ?? item.text?.content, !text.isEmpty {
                    print("[DEBUG] Category from richText: \(text)")
                    return text
                }
            }
        }

        if let checkbox = prop.checkbox {
            print("[DEBUG] Category from checkbox: \(checkbox)")
            return checkbox ? "Yes" : "No"
        }

        if let url = prop.url, !url.isEmpty {
            print("[DEBUG] Category from url: \(url)")
            return url
        }

        if let email = prop.email, !email.isEmpty {
            print("[DEBUG] Category from email: \(email)")
            return email
        }

        if let phone = prop.phoneNumber, !phone.isEmpty {
            print("[DEBUG] Category from phone: \(phone)")
            return phone
        }

        if let people = prop.people, !people.isEmpty {
            let names = people.compactMap { $0.name }
            print("[DEBUG] Category from people: \(names)")
            return names.joined(separator: ", ")
        }

        if let rollup = prop.rollup {
            if let number = rollup.number {
                print("[DEBUG] Category from rollup number: \(number)")
                return String(number)
            }
            if let array = rollup.array, !array.isEmpty {
                var results: [String] = []
                for item in array {
                    if let select = item.select, let name = select.name {
                        results.append(name)
                    }
                    if let title = item.title, !title.isEmpty {
                        for t in title {
                            if let text = t.plainText ?? t.text?.content, !text.isEmpty {
                                results.append(text)
                                break
                            }
                        }
                    }
                }
                if !results.isEmpty {
                    print("[DEBUG] Category from rollup array: \(results)")
                    return results.joined(separator: ", ")
                }
            }
        }

        if let relation = prop.relation, !relation.isEmpty {
            let relationIds = relation.compactMap { $0.id }
            print("[DEBUG] Found relation with IDs: \(relationIds)")
            if !relationIds.isEmpty {
                fetchRelationTitles(ids: relationIds) { [weak self] titles in
                    if !titles.isEmpty {
                        let category = titles.joined(separator: ", ")
                        print("[DEBUG] Category from relation: \(category)")
                    }
                }
            }
        }

        print("[DEBUG] No category value found in property")
        return nil
    }

    private func fetchRelationTitles(ids: [String], completion: @escaping ([String]) -> Void) {
        guard !token.isEmpty else {
            completion([])
            return
        }

        var titles: [String] = []
        let group = DispatchGroup()

        for id in ids {
            group.enter()

            let baseURL = AppConstants.API.notionBaseURL
            guard let url = URL(string: "\(baseURL)/pages/\(id)") else {
                group.leave()
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConstants.API.notionVersion, forHTTPHeaderField: "Notion-Version")

            URLSession.shared.dataTask(with: request) { data, _, error in
                defer { group.leave() }

                guard error == nil, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                if let props = json["properties"] as? [String: Any],
                   let titleProp = props["Name"] as? [String: Any],
                   let titleArray = titleProp["title"] as? [[String: Any]] {
                    for item in titleArray {
                        if let plainText = item["plain_text"] as? String, !plainText.isEmpty {
                            titles.append(plainText)
                            break
                        }
                    }
                } else if let titleProp = json["title"] as? [String: Any],
                          let titleArray = titleProp["title"] as? [[String: Any]] {
                    for item in titleArray {
                        if let plainText = item["plain_text"] as? String, !plainText.isEmpty {
                            titles.append(plainText)
                            break
                        }
                    }
                }
            }.resume()
        }

        group.notify(queue: .main) {
            completion(titles)
        }
    }

    private func extractDate(from row: NotionPage, column: String?) -> Date? {
        guard let column = column, let props = row.properties else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        if let prop = props[column], let dateObj = prop.date, let start = dateObj.start {
            if let date = formatter.date(from: start) {
                return date
            }
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            return dateOnlyFormatter.date(from: start)
        }

        if !row.createdTime.isEmpty {
            if let date = formatter.date(from: row.createdTime) {
                return date
            }
        }

        return Date()
    }
}
