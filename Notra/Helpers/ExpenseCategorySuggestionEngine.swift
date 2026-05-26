import Foundation

enum MatchStrength: Int, Comparable {
    case none = 0
    case weak = 1
    case strong = 2
    case exact = 3

    static func < (lhs: MatchStrength, rhs: MatchStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CategorySuggestion {
    let displayName: String
    let fieldType: NotionPropertyType
    let value: SuggestedCategoryValue
    let count: Int
    let confidence: Double
}

enum SuggestedCategoryValue: Equatable {
    case relation(id: String, title: String)
    case select(name: String)
    case status(name: String)
    case multiSelect(name: String)
}

final class ExpenseCategorySuggestionEngine {

    private var merchantMap: [String: [MerchantCategory]] = [:]
    private var totalExpensesScanned = 0

    init() {
        rebuild(categoryPropertyName: "")
    }

    func rebuild(categoryPropertyName: String) {
        merchantMap.removeAll()
        totalExpensesScanned = 0

        let expenses = SessionCacheManager.shared.allExpenses
        for expense in expenses {
            guard let normalizedTitle = normalize(expense.title), !normalizedTitle.isEmpty else { continue }
            guard let entry = extractEntry(from: expense, propertyName: categoryPropertyName) else { continue }

            var categories = merchantMap[normalizedTitle] ?? []
            if let idx = categories.firstIndex(where: { $0.matches(entry) }) {
                categories[idx].count += 1
            } else {
                categories.append(MerchantCategory(displayName: entry.displayName, value: entry.value, count: 1))
            }
            merchantMap[normalizedTitle] = categories
            totalExpensesScanned += 1
        }
    }

    func suggestions(for title: String) -> [CategorySuggestion] {
        let normalizedInput = normalize(title) ?? ""
        guard normalizedInput.count >= 3 else { return [] }

        var matchedCategories: [CategoryKey: Int] = [:]
        var totalMatched = 0
        var bestStrength: MatchStrength = .none

        for (merchantKey, categories) in merchantMap {
            let normalizedMerchant = normalize(merchantKey) ?? ""
            let strength = matchStrength(input: normalizedInput, merchant: normalizedMerchant)
            guard strength != .none else { continue }

            for mc in categories {
                let key = CategoryKey(displayName: mc.displayName, value: mc.value)
                matchedCategories[key, default: 0] += mc.count
                totalMatched += mc.count
            }

            if strength > bestStrength { bestStrength = strength }
        }

        guard totalMatched >= 1 else { return [] }

        let suggestions: [CategorySuggestion] = matchedCategories.compactMap { key, count in
            let confidence = Double(count) / Double(totalMatched)

            let canSuggest: Bool
            if totalMatched >= 2 {
                canSuggest = confidence >= 0.5
            } else {
                canSuggest = confidence >= 0.5 && bestStrength >= .strong
            }
            guard canSuggest else { return nil }

            let fieldType: NotionPropertyType
            switch key.value {
            case .relation: fieldType = .relation
            case .select: fieldType = .select
            case .status: fieldType = .status
            case .multiSelect: fieldType = .multiSelect
            }
            return CategorySuggestion(
                displayName: key.displayName,
                fieldType: fieldType,
                value: key.value,
                count: count,
                confidence: confidence
            )
        }

        return suggestions
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.confidence != b.confidence { return a.confidence > b.confidence }
                return a.displayName < b.displayName
            }
            .prefix(3)
            .map { $0 }
    }

    func noteSavedExpense(title: String, entry: (displayName: String, value: SuggestedCategoryValue)?) {
        guard let normalizedTitle = normalize(title), !normalizedTitle.isEmpty else { return }
        guard let entry = entry else { return }

        var categories = merchantMap[normalizedTitle] ?? []
        if let idx = categories.firstIndex(where: { $0.matches(entry) }) {
            categories[idx].count += 1
        } else {
            categories.append(MerchantCategory(displayName: entry.displayName, value: entry.value, count: 1))
        }
        merchantMap[normalizedTitle] = categories
        totalExpensesScanned += 1
    }

    // MARK: - Private

    private struct MerchantCategory {
        let displayName: String
        let value: SuggestedCategoryValue
        var count: Int

        func matches(_ other: (displayName: String, value: SuggestedCategoryValue)) -> Bool {
            return value == other.value
        }
    }

    private struct CategoryKey: Hashable {
        let displayName: String
        let value: SuggestedCategoryValue

        func hash(into hasher: inout Hasher) {
            switch value {
            case .relation(let id, _):
                hasher.combine("relation:\(id)")
            case .select(let name):
                hasher.combine("select:\(name)")
            case .status(let name):
                hasher.combine("status:\(name)")
            case .multiSelect(let name):
                hasher.combine("multiSelect:\(name)")
            }
        }

        static func == (lhs: CategoryKey, rhs: CategoryKey) -> Bool {
            switch (lhs.value, rhs.value) {
            case (.relation(let lid, _), .relation(let rid, _)): return lid == rid
            case (.select(let ln), .select(let rn)): return ln == rn
            case (.status(let ln), .status(let rn)): return ln == rn
            case (.multiSelect(let ln), .multiSelect(let rn)): return ln == rn
            default: return false
            }
        }
    }

    private func extractEntry(from expense: NormalizedTransaction, propertyName: String) -> (displayName: String, value: SuggestedCategoryValue)? {
        if !propertyName.isEmpty, let raw = expense.rawProperties?[propertyName] {
            if let selectName = raw.select?.name {
                return (selectName, .select(name: selectName))
            }
            if let multiSelect = raw.multiSelect, let first = multiSelect.compactMap({ $0.name }).first {
                return (first, .multiSelect(name: first))
            }
            if let relation = raw.relation, let firstId = relation.compactMap({ $0.id }).first {
                let title = expense.category ?? firstId
                return (title, .relation(id: firstId, title: title))
            }
            if raw.type == "status", let selectName = raw.select?.name {
                return (selectName, .status(name: selectName))
            }
        }

        guard let categoryString = expense.category, !categoryString.isEmpty else { return nil }
        return (categoryString, .select(name: categoryString))
    }

    private func normalize(_ text: String) -> String? {
        var s = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        let punctuation = CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "-'"))
        s = s.components(separatedBy: punctuation).joined()

        s = s.components(separatedBy: CharacterSet.decimalDigits).joined()

        let noiseWords: Set<String> = ["store", "order", "purchase", "transaction", "inc", "llc", "com", "ltd", "corp"]
        let words = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty && !noiseWords.contains($0) }
        guard !words.isEmpty else { return nil }

        s = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    private func matchStrength(input: String, merchant: String) -> MatchStrength {
        if input == merchant { return .exact }

        let inputTokens = input.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let merchantTokens = merchant.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if let firstInput = inputTokens.first, let firstMerchant = merchantTokens.first,
           firstInput == firstMerchant {
            return .strong
        }

        if merchant.contains(input) || input.contains(merchant) { return .weak }

        return .none
    }
}
