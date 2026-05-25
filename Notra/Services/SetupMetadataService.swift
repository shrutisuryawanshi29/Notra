import Foundation

final class SetupMetadataService {
    static let shared = SetupMetadataService()

    private init() {}

    // MARK: - Health status enum

    enum Health {
        case good(String)
        case warning(String)
        case error(String)
        case unknown(String)

        var displayText: String {
            switch self {
            case .good(let t), .warning(let t), .error(let t), .unknown(let t): return t
            }
        }
    }

    // MARK: - Token

    var isTokenSaved: Bool {
        UserDefaultsManager.shared.notionToken != nil
    }

    var tokenDisplay: String {
        isTokenSaved ? "••••••••" : "Not set"
    }

    // MARK: - Page

    var pageTitle: String? {
        UserDefaultsManager.shared.selectedPageTitle
    }

    var pageId: String? {
        UserDefaultsManager.shared.selectedPageId
    }

    // MARK: - Databases

    var expenseDatabase: DatabaseMappingData? {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        return mappings.values.first(where: { $0.role == .expense })
    }

    var incomeDatabase: DatabaseMappingData? {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        return mappings.values.first(where: { $0.role == .income })
    }

    var ignoredDatabaseTitles: [String] {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        return mappings.values.filter { $0.role == .ignore }.map(\.databaseTitle)
    }

    // MARK: - Column Mapping Display

    var expenseMappingSummary: String {
        guard let db = expenseDatabase, let m = db.columnMapping else { return "Not configured" }
        return mappingDisplayItems(for: m).map { "\($0.0): \($0.1)" }.joined(separator: " · ")
    }

    var incomeMappingSummary: String {
        guard let db = incomeDatabase, let m = db.columnMapping else { return "Not configured" }
        return mappingDisplayItems(for: m).map { "\($0.0): \($0.1)" }.joined(separator: " · ")
    }

    private func mappingDisplayItems(for mapping: ColumnMapping) -> [(String, String)] {
        var items: [(String, String)] = []
        if let t = mapping.titleColumn { items.append(("Title", t)) }
        if let a = mapping.amountColumn { items.append(("Amount", a)) }
        if let c = mapping.categoryColumn { items.append(("Category", c)) }
        if let d = mapping.dateColumn { items.append(("Date", d)) }
        return items
    }

    // MARK: - Health Checks

    var categoryRelationHealth: Health {
        guard let db = expenseDatabase, let m = db.columnMapping else {
            return .unknown("No expense mapping")
        }
        guard let dsId = m.categoryRelationDataSourceId, !dsId.isEmpty else {
            return .unknown("Category is not a relation")
        }
        return .good("Category relation detected")
    }

    var monthClassificationHealth: Health {
        guard let expenseDb = expenseDatabase else {
            return .unknown("No expense database")
        }
        guard let schema = SessionCacheManager.shared.getDatabaseSchema(databaseId: expenseDb.databaseId) else {
            return .unknown("Detecting...")
        }
        let hasMC = schema.contains { name, type in
            type.lowercased() == "relation" && name.lowercased().contains("month classification")
        }
        if hasMC {
            return .good("Month Classification detected")
        }
        return .warning("Month Classification not found")
    }

    var budgetColumnHealth: Health {
        guard let db = expenseDatabase, let m = db.columnMapping else {
            return .unknown("No expense database")
        }
        guard let dsId = m.categoryRelationDataSourceId, !dsId.isEmpty else {
            return .unknown("No category relation")
        }

        let hasCategoryData = SessionCacheManager.shared.getCategoryLookup(for: dsId) != nil

        var targetDbId: String?
        let relationTargets = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: db.databaseId)
        if let catCol = m.categoryColumn, let tid = relationTargets?[catCol] {
            targetDbId = tid
        }

        if let tid = targetDbId, let schema = SessionCacheManager.shared.getDatabaseSchema(databaseId: tid) {
            let budgetKeywords = ["monthly budget", "budget", "limit"]
            let hasBudgetCol = schema.contains { name, type in
                guard type.lowercased() == "number" else { return false }
                let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
                return budgetKeywords.contains { lower == $0 || lower.contains($0) }
            }
            if hasBudgetCol {
                return .good("Monthly budget column found")
            }
            return .warning("Monthly Budget column not found")
        }

        if hasCategoryData {
            return .warning("Monthly Budget column not found")
        }

        return .unknown("Detecting...")
    }

    // MARK: - Last Sync

    var lastSyncDate: Date? {
        SessionCacheManager.shared.lastLoadedMonth
    }

    var lastSyncDisplay: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Async Schema Loading

    func loadHealthData(completion: @escaping () -> Void) {
        guard let token = UserDefaultsManager.shared.notionToken else {
            completion()
            return
        }

        guard let expenseDb = expenseDatabase else {
            completion()
            return
        }

        let group = DispatchGroup()
        let dbId = expenseDb.databaseId
        let schemaCached = SessionCacheManager.shared.getDatabaseSchema(databaseId: dbId) != nil
        let targetsCached = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: dbId) != nil

        if !schemaCached || !targetsCached {
            group.enter()
            NotionService.shared.fetchDatabaseSchema(databaseId: dbId, token: token) { result in
                if case .success(let properties) = result {
                    var schema: [String: String] = [:]
                    var targets: [String: String] = [:]
                    for (name, prop) in properties {
                        guard let propDict = prop as? [String: Any], let type = propDict["type"] as? String else { continue }
                        schema[name] = type
                        if type == "relation", let relation = propDict["relation"] as? [String: Any], let targetDbId = relation["database_id"] as? String {
                            targets[name] = targetDbId
                        }
                    }
                    SessionCacheManager.shared.saveDatabaseSchema(databaseId: dbId, schema: schema)
                    if !targets.isEmpty {
                        SessionCacheManager.shared.saveRelationTargetDbIds(databaseId: dbId, mapping: targets)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            let relationTargets = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: dbId)
            let catCol = expenseDb.columnMapping?.categoryColumn
            let targetDbId = catCol.flatMap { relationTargets?[$0] }

            if let tid = targetDbId, SessionCacheManager.shared.getDatabaseSchema(databaseId: tid) == nil {
                group.enter()
                NotionService.shared.fetchDatabaseSchema(databaseId: tid, token: token) { result in
                    if case .success(let properties) = result {
                        var schema: [String: String] = [:]
                        for (name, prop) in properties {
                            guard let propDict = prop as? [String: Any], let type = propDict["type"] as? String else { continue }
                            schema[name] = type
                        }
                        SessionCacheManager.shared.saveDatabaseSchema(databaseId: tid, schema: schema)
                    }
                    group.leave()
                }

                group.notify(queue: .main) {
                    completion()
                }
            } else {
                completion()
            }
        }
    }
}
