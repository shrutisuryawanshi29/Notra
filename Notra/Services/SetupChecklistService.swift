import Foundation

final class SetupChecklistService {
    static let shared = SetupChecklistService()

    private init() {}

    enum CheckStatus {
        case pass
        case warning
        case fail
        case unknown

        var indicator: String {
            switch self {
            case .pass: return "✓"
            case .warning: return "⚠"
            case .fail: return "✗"
            case .unknown: return "○"
            }
        }
    }

    struct CheckItem {
        let id: String
        let title: String
        let message: String
        let status: CheckStatus
        let isRequired: Bool
    }

    // MARK: - Required checks

    var requiredChecks: [CheckItem] {
        [
            tokenCheck,
            pageCheck,
            expenseDbCheck,
            incomeDbCheck,
            expenseTitleCheck,
            expenseAmountCheck,
            expenseDateCheck,
            expenseCategoryCheck,
            incomeTitleCheck,
            incomeAmountCheck,
            incomeDateCheck,
            incomeSourceCheck
        ]
    }

    var recommendedChecks: [CheckItem] {
        [
            categoryRelationCheck,
            monthClassificationCheck,
            relationOptionsCheck,
            budgetColumnCheck
        ]
    }

    var allChecks: [CheckItem] {
        requiredChecks + recommendedChecks
    }

    var hasFails: Bool {
        requiredChecks.contains { $0.status == .fail }
    }

    var hasWarnings: Bool {
        allChecks.contains { $0.status == .warning }
    }

    // MARK: - Individual Checks

    private var tokenCheck: CheckItem {
        let saved = UserDefaultsManager.shared.notionToken != nil
        return CheckItem(
            id: "token",
            title: "Notion token connected",
            message: saved ? "Token saved" : "No token configured",
            status: saved ? .pass : .fail,
            isRequired: true
        )
    }

    private var pageCheck: CheckItem {
        let saved = UserDefaultsManager.shared.selectedPageId != nil
        return CheckItem(
            id: "page",
            title: "Main page selected",
            message: saved ? (UserDefaultsManager.shared.selectedPageTitle ?? "Page selected") : "No page selected",
            status: saved ? .pass : .fail,
            isRequired: true
        )
    }

    private var expenseDbCheck: CheckItem {
        let db = mappings.first(where: { $0.role == .expense })
        return CheckItem(
            id: "expenseDb",
            title: "Expense database assigned",
            message: db.map { $0.databaseTitle } ?? "No expense database",
            status: db != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var incomeDbCheck: CheckItem {
        let db = mappings.first(where: { $0.role == .income })
        return CheckItem(
            id: "incomeDb",
            title: "Income database assigned",
            message: db.map { $0.databaseTitle } ?? "No income database",
            status: db != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var expenseTitleCheck: CheckItem {
        let col = expenseMapping?.titleColumn
        return CheckItem(
            id: "expenseTitle",
            title: "Expense title mapped",
            message: col.map { "Title → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var expenseAmountCheck: CheckItem {
        let col = expenseMapping?.amountColumn
        return CheckItem(
            id: "expenseAmount",
            title: "Expense amount mapped",
            message: col.map { "Amount → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var expenseDateCheck: CheckItem {
        let col = expenseMapping?.dateColumn
        return CheckItem(
            id: "expenseDate",
            title: "Expense date mapped",
            message: col.map { "Date → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var expenseCategoryCheck: CheckItem {
        let col = expenseMapping?.categoryColumn
        return CheckItem(
            id: "expenseCategory",
            title: "Expense category mapped",
            message: col.map { "Category → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var incomeTitleCheck: CheckItem {
        let col = incomeMapping?.titleColumn
        return CheckItem(
            id: "incomeTitle",
            title: "Income title mapped",
            message: col.map { "Title → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var incomeAmountCheck: CheckItem {
        let col = incomeMapping?.amountColumn
        return CheckItem(
            id: "incomeAmount",
            title: "Income amount mapped",
            message: col.map { "Amount → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var incomeDateCheck: CheckItem {
        let col = incomeMapping?.dateColumn
        return CheckItem(
            id: "incomeDate",
            title: "Income date mapped",
            message: col.map { "Date → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var incomeSourceCheck: CheckItem {
        let col = incomeMapping?.categoryColumn
        return CheckItem(
            id: "incomeSource",
            title: "Income source mapped",
            message: col.map { "Source → \($0)" } ?? "Not mapped",
            status: col != nil ? .pass : .fail,
            isRequired: true
        )
    }

    private var categoryRelationCheck: CheckItem {
        let dsId = expenseMapping?.categoryRelationDataSourceId
        let valid = dsId != nil && !dsId!.isEmpty
        return CheckItem(
            id: "categoryRelation",
            title: "Expense category is relation",
            message: valid ? "Category uses a relation database" : "Category is not a relation",
            status: valid ? .pass : .warning,
            isRequired: false
        )
    }

    private var monthClassificationCheck: CheckItem {
        guard let expenseDbId = expenseDatabase?.databaseId else {
            return CheckItem(id: "monthClassification", title: "Month Classification detected", message: "No expense database", status: .unknown, isRequired: false)
        }
        guard let schema = SessionCacheManager.shared.getDatabaseSchema(databaseId: expenseDbId) else {
            return CheckItem(id: "monthClassification", title: "Month Classification detected", message: "Detecting...", status: .unknown, isRequired: false)
        }
        let hasMC = schema.contains { $0.value.lowercased() == "relation" && $0.key.lowercased().contains("month classification") }
        return CheckItem(
            id: "monthClassification",
            title: "Month Classification detected",
            message: hasMC ? "Found in expense database" : "Not found in expense database",
            status: hasMC ? .pass : .warning,
            isRequired: false
        )
    }

    private var relationOptionsCheck: CheckItem {
        guard let dsId = expenseMapping?.categoryRelationDataSourceId, !dsId.isEmpty else {
            return CheckItem(id: "relationOptions", title: "Category relation data loaded", message: "Not a relation", status: .unknown, isRequired: false)
        }
        let cached = SessionCacheManager.shared.getCategoryLookup(for: dsId) != nil
        return CheckItem(
            id: "relationOptions",
            title: "Category relation data loaded",
            message: cached ? "Relation options available" : "Open Dashboard to load",
            status: cached ? .pass : .warning,
            isRequired: false
        )
    }

    private var budgetColumnCheck: CheckItem {
        guard let db = expenseDatabase, let m = db.columnMapping, let dsId = m.categoryRelationDataSourceId, !dsId.isEmpty else {
            return CheckItem(id: "budgetColumn", title: "Monthly Budget column found", message: "No category relation", status: .unknown, isRequired: false)
        }

        let relationTargets = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: db.databaseId)
        let targetDbId = m.categoryColumn.flatMap { relationTargets?[$0] }

        if let tid = targetDbId, let schema = SessionCacheManager.shared.getDatabaseSchema(databaseId: tid) {
            let keywords = ["monthly budget", "budget", "limit"]
            let hasBudget = schema.contains { name, type in
                guard type.lowercased() == "number" else { return false }
                let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
                return keywords.contains { lower == $0 || lower.contains($0) }
            }
            return CheckItem(
                id: "budgetColumn",
                title: "Monthly Budget column found",
                message: hasBudget ? "Budget column detected in category database" : "No budget column found",
                status: hasBudget ? .pass : .warning,
                isRequired: false
            )
        }

        let hasCategoryData = SessionCacheManager.shared.getCategoryLookup(for: dsId) != nil
        return CheckItem(
            id: "budgetColumn",
            title: "Monthly Budget column found",
            message: hasCategoryData ? "No budget column found" : "Detecting...",
            status: hasCategoryData ? .warning : .unknown,
            isRequired: false
        )
    }
}

private extension SetupChecklistService {
    var mappings: [DatabaseMappingData] {
        Array(ColumnMappingService.shared.loadDatabaseMappings().values)
    }

    var expenseDatabase: DatabaseMappingData? {
        mappings.first(where: { $0.role == .expense })
    }

    var incomeDatabase: DatabaseMappingData? {
        mappings.first(where: { $0.role == .income })
    }

    var expenseMapping: ColumnMapping? {
        expenseDatabase?.columnMapping
    }

    var incomeMapping: ColumnMapping? {
        incomeDatabase?.columnMapping
    }
}
