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
            let split = extractSplitMetadata(from: row, column: columnMapping.expenseAppMetadataProperty)
            let paidAmount = split?.paidAmount
            let date = extractDate(from: row, column: columnMapping.dateColumn) ?? Date()

            print("[DEBUG] TRANSACTION: title='\(title)', amount=\(amount), date=\(date), monthKey=\(MonthMetadata(date: date).monthKey)")

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
                    paidAmount: paidAmount.map(abs),
                    category: category,
                    date: date,
                    databaseId: mapping.databaseId,
                    databaseRole: role,
                    rawProperties: row.properties,
                    splitMetadata: split
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
                    paidAmount: paidAmount.map(abs),
                    category: category,
                    date: date,
                    databaseId: mapping.databaseId,
                    databaseRole: role,
                    rawProperties: row.properties,
                    splitMetadata: split
                )

                mutex.lock()
                transactions.append(transaction)
                mutex.unlock()
            }
        }

        group.notify(queue: .main) {
            var seen = Set<String>()
            var uniqueTransactions: [NormalizedTransaction] = []
            for t in transactions {
                if !seen.contains(t.id) {
                    seen.insert(t.id)
                    uniqueTransactions.append(t)
                }
            }
            let duplicateCount = transactions.count - uniqueTransactions.count
            if duplicateCount > 0 {
                print("[DEBUG] Removed \(duplicateCount) duplicate transactions")
            }
            print("[DEBUG] NORMALIZED: \(uniqueTransactions.count) transactions for role \(role)")
            let total = uniqueTransactions.reduce(0) { $0 + $1.amount }
            print("[DEBUG] TOTAL AMOUNT: $\(total)")
            completion(uniqueTransactions)
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
            let split = extractSplitMetadata(from: row, column: columnMapping.expenseAppMetadataProperty)
            let paidAmount = split?.paidAmount
            let category = extractCategory(from: row, column: columnMapping.categoryColumn, mapping: mapping)
            let date = extractDate(from: row, column: columnMapping.dateColumn) ?? Date()

            if columnMapping.dateColumn != nil && row.properties?[columnMapping.dateColumn!]?.date?.start == nil {
                print("[DEBUG] Date column '\(columnMapping.dateColumn!)' has no date value for: \(title)")
            }

            print("[DEBUG] Row: title=\(title), amount=\(amount), category=\(category ?? "NIL"), date=\(date)")

            let transaction = NormalizedTransaction(
                id: row.id,
                title: title,
                amount: abs(amount),
                paidAmount: paidAmount.map(abs),
                category: category,
                date: date,
                databaseId: mapping.databaseId,
                databaseRole: role,
                rawProperties: row.properties,
                splitMetadata: split
            )
            transactions.append(transaction)
        }

        var seen = Set<String>()
        var uniqueTransactions: [NormalizedTransaction] = []
        for t in transactions {
            if !seen.contains(t.id) {
                seen.insert(t.id)
                uniqueTransactions.append(t)
            }
        }

        return uniqueTransactions
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

    private func extractSplitMetadata(from row: NotionPage, column: String?) -> SplitMetadata? {
        guard let column = column, let props = row.properties else {
            #if DEBUG
            print("[SplitDetailsParser] No column or props")
            #endif
            return nil
        }
        guard let prop = props[column], let richText = prop.richText else {
            #if DEBUG
            print("[SplitDetailsParser] No property or richText for column: \(column)")
            #endif
            return nil
        }

        for item in richText {
            guard let text = item.plainText ?? item.text?.content else { continue }

            #if DEBUG
            print("[SplitDetailsParser] Raw metadata: \(text)")
            #endif

            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let split = json["split"] as? [String: Any],
                  let enabled = split["enabled"] as? Bool, enabled else {
                #if DEBUG
                print("[SplitDetailsParser] Failed to parse metadata")
                #endif
                continue
            }

            let paid = split["paidAmount"] as? Double ?? 0
            let myShare = split["myShare"] as? Double ?? 0
            let theyOwe = split["theyOwe"] as? Double ?? max(paid - myShare, 0)
            let type = split["type"] as? String
            let status = split["status"] as? String
            let splitWith = split["splitWith"] as? String
            let rawInputs = split["inputs"] as? [String: Any]
            let inputs: SplitInputs?
            if let ri = rawInputs {
                if let data = try? JSONSerialization.data(withJSONObject: ri),
                   let decoded = try? JSONDecoder().decode(SplitInputs.self, from: data) {
                    inputs = decoded
                } else {
                    inputs = nil
                }
            } else {
                inputs = nil
            }

            guard paid > 0 else {
                #if DEBUG
                print("[SplitDetailsParser] paidAmount <= 0, skipping")
                #endif
                continue
            }

            #if DEBUG
            print("[SplitDetailsParser] Parsed isSplit: true, paidAmount: \(paid), myShare: \(myShare), theyOwe: \(theyOwe), type: \(type ?? "nil"), status: \(status ?? "nil"), splitWith: \(splitWith ?? "nil"), inputs: \(rawInputs ?? [:])")
            #endif

            return SplitMetadata(
                enabled: true,
                paidAmount: paid,
                myShare: myShare,
                theyOwe: theyOwe,
                type: type,
                status: status,
                splitWith: splitWith,
                inputs: inputs
            )
        }

        #if DEBUG
        print("[SplitDetailsParser] No valid split metadata found in richText items: \(richText.count)")
        #endif
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
                let relationDbId = mapping.columnMapping?.categoryRelationDataSourceId ?? ""
                if let dbLookup = relationLookupMap[relationDbId], !dbLookup.isEmpty {
                    var names: [String] = []
                    for relationId in relationIds {
                        if let name = dbLookup[relationId] {
                            print("[DEBUG] Resolved category relation ID \(relationId) -> \(name)")
                            names.append(name)
                        }
                    }
                    if !names.isEmpty {
                        return names.joined(separator: ", ")
                    }
                }
                print("[DEBUG] Relation lookup not available for DB: \(relationDbId)")
            }
        }

        print("[DEBUG] No category value found in property")
        return nil
    }

    private func extractDate(from row: NotionPage, column: String?) -> Date? {
        guard let column = column, let props = row.properties else { return nil }

        if let prop = props[column], let dateObj = prop.date, let start = dateObj.start {
            if start.contains("T") {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                if let date = isoFormatter.date(from: start) {
                    return date
                }
            } else {
                let parts = start.components(separatedBy: "-")
                if parts.count == 3,
                   let year = Int(parts[0]),
                   let month = Int(parts[1]),
                   let day = Int(parts[2]) {
                    var components = DateComponents()
                    components.year = year
                    components.month = month
                    components.day = day
                    components.hour = 12
                    components.minute = 0
                    components.second = 0
                    return Calendar.current.date(from: components)
                }
            }
        }

        if !row.createdTime.isEmpty {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            if let date = isoFormatter.date(from: row.createdTime) {
                return date
            }

            let formatterWithTime = ISO8601DateFormatter()
            formatterWithTime.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            if let date = formatterWithTime.date(from: row.createdTime) {
                return date
            }
        }

        return Date()
    }
}
