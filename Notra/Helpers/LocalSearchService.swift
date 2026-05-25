import Foundation

enum LocalSearchService {

    static func transactionMatchesSearch(_ transaction: NormalizedTransaction, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let text = searchableText(for: transaction)
        return text.localizedCaseInsensitiveContains(trimmed)
    }

    static func searchableText(for transaction: NormalizedTransaction) -> String {
        var parts: [String] = []
        parts.append(transaction.title)

        if let category = transaction.category {
            parts.append(category)
        }

        parts.append(transaction.formattedAmount)
        parts.append(transaction.formattedDate)

        guard let raw = transaction.rawProperties else {
            return parts.joined(separator: " ").lowercased()
        }

        for (_, prop) in raw {
            if let rt = prop.richText {
                for item in rt {
                    if let text = item.plainText, !text.isEmpty {
                        parts.append(text)
                    }
                }
            }
            if let titles = prop.title {
                for item in titles {
                    if let text = item.plainText, !text.isEmpty {
                        parts.append(text)
                    }
                }
            }
            if let select = prop.select, let name = select.name {
                parts.append(name)
            }
            if let multiSelect = prop.multiSelect {
                for ms in multiSelect {
                    if let name = ms.name {
                        parts.append(name)
                    }
                }
            }
            if let relation = prop.relation {
                for rel in relation {
                    if let id = rel.id {
                        let titles = SessionCacheManager.shared.resolveRelationTitles(pageIds: [id])
                        if let title = titles.first {
                            parts.append(title)
                        }
                    }
                }
            }
            if let url = prop.url {
                parts.append(url)
            }
            if let email = prop.email {
                parts.append(email)
            }
            if let phone = prop.phoneNumber {
                parts.append(phone)
            }
            if let number = prop.number {
                parts.append(String(format: "%.2f", number))
            }
        }

        return parts.joined(separator: " ").lowercased()
    }
}
