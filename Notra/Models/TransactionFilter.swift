import Foundation

enum FilterCondition: String, CaseIterable {
    case contains
    case equals
    case notEquals
    case isEmpty
    case isNotEmpty
    case greaterThan
    case lessThan
    case between
    case before
    case after
    case isChecked
    case isUnchecked

    var displayName: String {
        switch self {
        case .contains: return "Contains"
        case .equals: return "Equals"
        case .notEquals: return "Is Not"
        case .isEmpty: return "Is Empty"
        case .isNotEmpty: return "Is Not Empty"
        case .greaterThan: return "Greater Than"
        case .lessThan: return "Less Than"
        case .between: return "Between"
        case .before: return "Before"
        case .after: return "After"
        case .isChecked: return "Is Checked"
        case .isUnchecked: return "Is Unchecked"
        }
    }

    static func conditions(for type: NotionPropertyType) -> [FilterCondition] {
        switch type {
        case .title, .richText, .url, .email, .phoneNumber:
            return [.contains, .equals, .isEmpty, .isNotEmpty]
        case .number:
            return [.equals, .greaterThan, .lessThan, .between, .isEmpty, .isNotEmpty]
        case .date:
            return [.before, .after, .between, .isEmpty, .isNotEmpty]
        case .select, .status:
            return [.equals, .notEquals, .isEmpty, .isNotEmpty]
        case .multiSelect:
            return [.contains, .notEquals, .isEmpty, .isNotEmpty]
        case .relation:
            return [.equals, .notEquals, .isEmpty, .isNotEmpty]
        case .checkbox:
            return [.isChecked, .isUnchecked]
        }
    }
}

struct TransactionFilter {
    let id: UUID
    var propertyName: String
    var propertyType: NotionPropertyType
    var condition: FilterCondition
    var value: FilterValue?

    init(
        id: UUID = UUID(),
        propertyName: String,
        propertyType: NotionPropertyType,
        condition: FilterCondition,
        value: FilterValue? = nil
    ) {
        self.id = id
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.condition = condition
        self.value = value
    }
}

enum FilterValue {
    case text(String)
    case number(Double)
    case numberRange(Double, Double)
    case date(Date)
    case dateRange(Date?, Date?)
    case select(String)
    case multiSelect(String)
    case relation(id: String, title: String)
    case checkbox(Bool)

    var displayString: String {
        let fmt: (Date) -> String = { d in
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: d)
        }
        switch self {
        case .text(let v): return v
        case .number(let v): return String(format: "%.2f", v)
        case .numberRange(let a, let b): return String(format: "%.2f – %.2f", a, b)
        case .date(let d): return fmt(d)
        case .dateRange(let f, let t):
            if let f = f, let t = t { return "\(fmt(f)) – \(fmt(t))" }
            if let f = f { return "From \(fmt(f))" }
            if let t = t { return "Until \(fmt(t))" }
            return ""
        case .select(let v): return v
        case .multiSelect(let v): return v
        case .relation(_, let t): return t
        case .checkbox(let v): return v ? "Checked" : "Unchecked"
        }
    }
}

struct DateRangeFilter {
    var fromDate: Date?
    var toDate: Date?

    var isActive: Bool {
        return fromDate != nil || toDate != nil
    }

    var displayString: String {
        let fmt: (Date) -> String = { d in
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: d)
        }
        if let f = fromDate, let t = toDate { return "\(fmt(f)) – \(fmt(t))" }
        if let f = fromDate { return "From \(fmt(f))" }
        if let t = toDate { return "Until \(fmt(t))" }
        return "No date range"
    }
}
