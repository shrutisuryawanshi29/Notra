import Foundation

final class FilterPanelViewModel {
    let databaseId: String
    let databaseRole: DatabaseRole
    let allProperties: [(name: String, type: NotionPropertyType)]
    let selectOptions: [String: [String]]
    let databaseIds: [String]
    let notionToken: String

    // Per-property relation options: [propertyName: [(id: String, title: String)]]
    private(set) var relationOptions: [String: [(id: String, title: String)]]

    // Tracks whether we've attempted to fetch options for each relation property
    private(set) var relationFetchAttempted: Set<String> = []

    var filterRows: [FilterRow] = []
    var dateRange = DateRangeFilter(fromDate: nil, toDate: nil)

    // Callbacks for the view controller to update cells
    var onRelationOptionsLoaded: ((String, [(id: String, title: String)]) -> Void)?

    struct FilterRow {
        let id: UUID
        var selectedProperty: (name: String, type: NotionPropertyType)?
        var selectedCondition: FilterCondition?
        var textValue: String?
        var numberValue: Double?
        var dateValue: Date?
        var selectValue: String?
        var relationValue: (id: String, title: String)?
        var multiSelectValue: String?

        init(id: UUID = UUID()) {
            self.id = id
        }
    }

    init(databaseId: String, databaseRole: DatabaseRole,
         allProperties: [(name: String, type: NotionPropertyType)],
         selectOptions: [String: [String]],
         relationOptions: [String: [(id: String, title: String)]],
         notionToken: String,
         databaseIds: [String]) {

        self.databaseId = databaseId
        self.databaseRole = databaseRole
        self.allProperties = allProperties
        self.selectOptions = selectOptions
        self.relationOptions = relationOptions
        self.notionToken = notionToken
        self.databaseIds = databaseIds
    }

    func addFilterRow() {
        filterRows.append(FilterRow())
    }

    func removeFilterRow(at index: Int) {
        guard index < filterRows.count else { return }
        filterRows.remove(at: index)
    }

    func clearAll() {
        filterRows.removeAll()
        dateRange = DateRangeFilter(fromDate: nil, toDate: nil)
    }

    func buildFilters() -> [TransactionFilter] {
        var result: [TransactionFilter] = []
        for row in filterRows {
            guard let prop = row.selectedProperty, let condition = row.selectedCondition else { continue }
            let value = buildValue(for: row, type: prop.type, condition: condition)
            result.append(TransactionFilter(
                id: row.id,
                propertyName: prop.name,
                propertyType: prop.type,
                condition: condition,
                value: value
            ))
        }
        return result
    }

    var hasActiveFilters: Bool {
        return !filterRows.isEmpty || dateRange.isActive
    }

    // MARK: - Relation Options Loading

    func relationOptions(for propertyName: String) -> [(id: String, title: String)] {
        return relationOptions[propertyName] ?? []
    }

    func loadRelationOptionsIfNeeded(for propertyName: String) {
        guard !propertyName.isEmpty else { return }

        // If we already have options (even empty from a known target), skip
        if relationOptions[propertyName] != nil {
            let existing = relationOptions[propertyName]!
            if !existing.isEmpty {
                return // already loaded
            }
            // Empty could mean "known target but no data" or "unknown target"
            // Check if we know the target DB ID
            for dbId in databaseIds {
                if let mapping = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: dbId),
                   let targetDbId = mapping[propertyName] {
                    // We know the target DB ID — check if relation data is cached
                    self.relationFetchAttempted.insert(propertyName)
                    if let data = SessionCacheManager.shared.getRelationTargetData(databaseId: targetDbId) {
                        let opts = data.map { (id: $0.key, title: $0.value) }.sorted { $0.title < $1.title }
                        self.relationOptions[propertyName] = opts
                        self.onRelationOptionsLoaded?(propertyName, opts)
                        return
                    }
                    // Know target ID but relation data not cached — fetch from API
                    fetchRelationData(targetDbId: targetDbId, for: propertyName)
                    return
                }
            }
            // Don't know target DB ID — try fetching schema
            relationFetchAttempted.insert(propertyName)
            fetchRelationTargetDbId(for: propertyName)
        }
    }

    private func fetchRelationTargetDbId(for propertyName: String) {
        for dbId in databaseIds {
            if SessionCacheManager.shared.getDatabaseSchema(databaseId: dbId) == nil {
                fetchAndCacheSchema(databaseId: dbId, for: propertyName)
                return
            }
        }
    }

    private func fetchAndCacheSchema(databaseId: String, for propertyName: String) {
        NotionService.shared.fetchDatabaseSchema(databaseId: databaseId, token: notionToken) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let properties):
                var relationMapping: [String: String] = [:]
                for (name, raw) in properties {
                    guard let dict = raw as? [String: Any], let type = dict["type"] as? String else { continue }
                    if type == "relation" {
                        if let relationConfig = dict["relation"] as? [String: Any],
                           let targetDbId = (relationConfig["database_id"] as? String) ?? (relationConfig["data_source_id"] as? String) {
                            relationMapping[name] = targetDbId
                        }
                    }
                }
                SessionCacheManager.shared.saveRelationTargetDbIds(databaseId: databaseId, mapping: relationMapping)

                // Retry loading relation options
                if let targetDbId = relationMapping[propertyName] {
                    self.relationFetchAttempted.insert(propertyName)
                    if let data = SessionCacheManager.shared.getRelationTargetData(databaseId: targetDbId) {
                        let opts = data.map { (id: $0.key, title: $0.value) }.sorted { $0.title < $1.title }
                        self.relationOptions[propertyName] = opts
                        self.onRelationOptionsLoaded?(propertyName, opts)
                    } else {
                        self.fetchRelationData(targetDbId: targetDbId, for: propertyName)
                    }
                }

            case .failure:
                self.relationFetchAttempted.insert(propertyName)
                self.onRelationOptionsLoaded?(propertyName, [])
            }
        }
    }

    private func fetchRelationData(targetDbId: String, for propertyName: String) {
        relationFetchAttempted.insert(propertyName)
        TransactionInsertService.shared.loadRelationOptions(databaseId: targetDbId, token: notionToken) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let options):
                SessionCacheManager.shared.saveRelationTargetData(databaseId: targetDbId,
                    lookup: Dictionary(uniqueKeysWithValues: options.map { ($0.id, $0.title) }))
                let sorted = options.sorted { $0.title < $1.title }
                self.relationOptions[propertyName] = sorted
                self.onRelationOptionsLoaded?(propertyName, sorted)
            case .failure:
                self.onRelationOptionsLoaded?(propertyName, [])
            }
        }
    }

    // MARK: - Value Builder

    private func buildValue(for row: FilterRow, type: NotionPropertyType, condition: FilterCondition) -> FilterValue? {
        if condition == .isEmpty || condition == .isNotEmpty || condition == .isChecked || condition == .isUnchecked {
            return nil
        }
        switch type {
        case .title, .richText, .url, .email, .phoneNumber:
            guard let v = row.textValue, !v.isEmpty else { return nil }
            return .text(v)
        case .number:
            if condition == .between {
                guard let v1 = row.numberValue else { return nil }
                return .numberRange(v1, v1)
            }
            guard let v = row.numberValue else { return nil }
            return .number(v)
        case .date:
            if condition == .between {
                return .dateRange(row.dateValue, row.dateValue)
            }
            guard let v = row.dateValue else { return nil }
            return .date(v)
        case .select, .status:
            guard let v = row.selectValue, !v.isEmpty else { return nil }
            return .select(v)
        case .multiSelect:
            guard let v = row.multiSelectValue, !v.isEmpty else { return nil }
            return .multiSelect(v)
        case .relation:
            guard let v = row.relationValue else { return nil }
            return .relation(id: v.id, title: v.title)
        case .checkbox:
            return .checkbox(condition == .isChecked)
        }
    }
}
