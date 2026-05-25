import Foundation

struct FilterEngine {

    static func applyFilters(
        to transactions: [NormalizedTransaction],
        filters: [TransactionFilter],
        dateRange: DateRangeFilter?,
        relationLookup: [String: [String: String]]?
    ) -> [NormalizedTransaction] {
        guard !filters.isEmpty || (dateRange?.isActive == true) else {
            return transactions
        }

        return transactions.filter { transaction in
            for filter in filters {
                if !matches(transaction: transaction, filter: filter, relationLookup: relationLookup) {
                    return false
                }
            }
            if let dr = dateRange, dr.isActive {
                if !matchesDateRange(transaction: transaction, dateRange: dr) {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Matching by Filter

    private static func matches(transaction: NormalizedTransaction, filter: TransactionFilter, relationLookup: [String: [String: String]]?) -> Bool {
        guard let props = transaction.rawProperties else {
            return filter.condition == .isEmpty || filter.condition == .isUnchecked || filter.condition == .isNotEmpty || filter.condition == .isChecked
        }
        guard let prop = props[filter.propertyName] else {
            return filter.condition == .isEmpty || filter.condition == .isUnchecked
        }

        switch filter.condition {
        case .isEmpty:
            return isValueEmpty(prop)
        case .isNotEmpty:
            return !isValueEmpty(prop)
        default:
            break
        }

        switch filter.propertyType {
        case .title, .richText, .url, .email, .phoneNumber:
            return matchText(prop: prop, condition: filter.condition, compareValue: filter.value)
        case .number:
            return matchNumber(prop: prop, condition: filter.condition, compareValue: filter.value)
        case .date:
            return matchDate(prop: prop, condition: filter.condition, compareValue: filter.value)
        case .select, .status:
            return matchSelect(prop: prop, condition: filter.condition, compareValue: filter.value)
        case .multiSelect:
            return matchMultiSelect(prop: prop, condition: filter.condition, compareValue: filter.value)
        case .relation:
            return matchRelation(prop: prop, condition: filter.condition, compareValue: filter.value, relationLookup: relationLookup)
        case .checkbox:
            return matchCheckbox(prop: prop, condition: filter.condition)
        }
    }

    // MARK: - Value Extraction Helpers

    private static func getTextValue(_ prop: NotionPropertyValue) -> String? {
        if let t = prop.title, let first = t.first {
            return first.plainText ?? first.text?.content
        }
        if let rt = prop.richText, let first = rt.first {
            return first.plainText ?? first.text?.content
        }
        return nil
    }

    private static func getNumberValue(_ prop: NotionPropertyValue) -> Double? {
        return prop.number
    }

    private static func getDateValue(_ prop: NotionPropertyValue) -> Date? {
        guard let start = prop.date?.start else { return nil }
        if start.contains("T") {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            return iso.date(from: start)
        }
        let parts = start.components(separatedBy: "-")
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
            var comp = DateComponents()
            comp.year = y; comp.month = m; comp.day = d
            comp.hour = 12
            return Calendar.current.date(from: comp)
        }
        return nil
    }

    private static func getSelectValue(_ prop: NotionPropertyValue) -> String? {
        return prop.select?.name
    }

    private static func getMultiSelectValues(_ prop: NotionPropertyValue) -> [String] {
        return prop.multiSelect?.compactMap { $0.name } ?? []
    }

    private static func getRelationIds(_ prop: NotionPropertyValue) -> [String] {
        return prop.relation?.compactMap { $0.id } ?? []
    }

    private static func getCheckboxValue(_ prop: NotionPropertyValue) -> Bool {
        return prop.checkbox ?? false
    }

    // MARK: - Empty Check

    private static func isValueEmpty(_ prop: NotionPropertyValue) -> Bool {
        if let type = prop.type {
            switch type {
            case "title", "rich_text":
                return getTextValue(prop)?.isEmpty ?? true
            case "number":
                return prop.number == nil
            case "select", "status":
                return prop.select?.name?.isEmpty ?? true
            case "multi_select":
                return prop.multiSelect?.isEmpty ?? true
            case "date":
                return prop.date?.start == nil
            case "relation":
                return prop.relation?.isEmpty ?? true
            case "checkbox":
                return prop.checkbox == nil
            default:
                return true
            }
        }
        return true
    }

    // MARK: - Type-Specific Matching

    private static func matchText(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?) -> Bool {
        guard let val = getTextValue(prop)?.lowercased() else { return false }
        guard let compareValue = compareValue else { return true }
        switch condition {
        case .contains:
            if case .text(let cv) = compareValue { return val.contains(cv.lowercased()) }
            return false
        case .equals:
            if case .text(let cv) = compareValue { return val == cv.lowercased() }
            return false
        default:
            return true
        }
    }

    private static func matchNumber(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?) -> Bool {
        guard let val = getNumberValue(prop) else { return false }
        guard let compareValue = compareValue else { return true }
        switch condition {
        case .equals:
            if case .number(let cv) = compareValue { return val == cv }
            return false
        case .greaterThan:
            if case .number(let cv) = compareValue { return val > cv }
            return false
        case .lessThan:
            if case .number(let cv) = compareValue { return val < cv }
            return false
        case .between:
            if case .numberRange(let a, let b) = compareValue { return val >= a && val <= b }
            return false
        default:
            return true
        }
    }

    private static func matchDate(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?) -> Bool {
        guard let val = getDateValue(prop) else { return false }
        guard let compareValue = compareValue else { return true }
        switch condition {
        case .before:
            if case .date(let cv) = compareValue { return val < cv }
            if case .dateRange(_, let to) = compareValue, let to = to { return val <= to }
            return false
        case .after:
            if case .date(let cv) = compareValue { return val >= cv }
            if case .dateRange(let from, _) = compareValue, let from = from { return val >= from }
            return false
        case .between:
            if case .dateRange(let from, let to) = compareValue {
                if let f = from, let t = to { return val >= f && val <= t }
                if let f = from { return val >= f }
                if let t = to { return val <= t }
            }
            return false
        default:
            return true
        }
    }

    private static func matchSelect(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?) -> Bool {
        guard let val = getSelectValue(prop)?.lowercased() else { return false }
        guard let compareValue = compareValue else { return true }
        switch condition {
        case .equals:
            if case .select(let cv) = compareValue { return val == cv.lowercased() }
            return false
        case .notEquals:
            if case .select(let cv) = compareValue { return val != cv.lowercased() }
            return false
        default:
            return true
        }
    }

    private static func matchMultiSelect(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?) -> Bool {
        let vals = getMultiSelectValues(prop).map { $0.lowercased() }
        guard let compareValue = compareValue else { return !vals.isEmpty }
        switch condition {
        case .contains:
            if case .multiSelect(let cv) = compareValue { return vals.contains(cv.lowercased()) }
            return false
        case .notEquals:
            if case .multiSelect(let cv) = compareValue { return !vals.contains(cv.lowercased()) }
            return false
        default:
            return true
        }
    }

    private static func matchRelation(prop: NotionPropertyValue, condition: FilterCondition, compareValue: FilterValue?, relationLookup: [String: [String: String]]?) -> Bool {
        let ids = getRelationIds(prop)
        guard let compareValue = compareValue else { return !ids.isEmpty }
        switch condition {
        case .equals:
            if case .relation(let targetId, _) = compareValue { return ids.contains(targetId) }
            return false
        case .notEquals:
            if case .relation(let targetId, _) = compareValue { return !ids.contains(targetId) }
            return false
        default:
            return true
        }
    }

    private static func matchCheckbox(prop: NotionPropertyValue, condition: FilterCondition) -> Bool {
        let val = getCheckboxValue(prop)
        switch condition {
        case .isChecked: return val == true
        case .isUnchecked: return val == false
        default: return true
        }
    }

    // MARK: - Date Range

    private static func matchesDateRange(transaction: NormalizedTransaction, dateRange: DateRangeFilter) -> Bool {
        let txDate = transaction.date
        if let from = dateRange.fromDate, let to = dateRange.toDate {
            let dayAfterTo = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
            return txDate >= from && txDate < dayAfterTo
        }
        if let from = dateRange.fromDate {
            return txDate >= from
        }
        if let to = dateRange.toDate {
            let dayAfterTo = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
            return txDate < dayAfterTo
        }
        return true
    }
}
