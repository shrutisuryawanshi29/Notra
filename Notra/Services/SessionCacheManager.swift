//
//  SessionCacheManager.swift
//  Notra
//

import Foundation

final class SessionCacheManager {
    static let shared = SessionCacheManager()

    private var cache: [String: Any] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: - Transaction Cache

    private var expenses: [NormalizedTransaction] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["expenses"] as? [NormalizedTransaction] ?? []
        }
        set {
            lock.lock()
            cache["expenses"] = newValue
            lock.unlock()
            print("[SessionCache] Expense cache count: \(newValue.count)")
        }
    }

    private var incomes: [NormalizedTransaction] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["incomes"] as? [NormalizedTransaction] ?? []
        }
        set {
            lock.lock()
            cache["incomes"] = newValue
            lock.unlock()
            print("[SessionCache] Income cache count: \(newValue.count)")
        }
    }

    private var expenseSections: [GroupedTransactionSection] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["expenseSections"] as? [GroupedTransactionSection] ?? []
        }
        set {
            lock.lock()
            cache["expenseSections"] = newValue
            lock.unlock()
            print("[SessionCache] Grouped expense section count: \(newValue.count)")
        }
    }

    private var incomeSections: [GroupedTransactionSection] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["incomeSections"] as? [GroupedTransactionSection] ?? []
        }
        set {
            lock.lock()
            cache["incomeSections"] = newValue
            lock.unlock()
            print("[SessionCache] Grouped income section count: \(newValue.count)")
        }
    }

    private var fetchedMonths: [MonthMetadata] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["fetchedMonths"] as? [MonthMetadata] ?? []
        }
        set {
            lock.lock()
            cache["fetchedMonths"] = newValue
            lock.unlock()
        }
    }

    // MARK: - Public Accessors

    var allExpenses: [NormalizedTransaction] {
        return expenses
    }

    var allIncomes: [NormalizedTransaction] {
        return incomes
    }

    var groupedExpenses: [GroupedTransactionSection] {
        return expenseSections
    }

    var groupedIncomes: [GroupedTransactionSection] {
        return incomeSections
    }

    // MARK: - Cache Population

    func populateCache(expenses: [NormalizedTransaction], incomes: [NormalizedTransaction]) {
        print("[SessionCache] Cache population started")
        self.expenses = expenses
        self.incomes = incomes
        self.expenseSections = groupTransactionsByDate(expenses)
        self.incomeSections = groupTransactionsByDate(incomes)
        print("[SessionCache] Cache population complete")
    }

    func setFetchedMonths(_ months: [MonthMetadata]) {
        self.fetchedMonths = months
    }

    func getFetchedMonths() -> [MonthMetadata] {
        return fetchedMonths
    }

    // MARK: - Grouping

    private func groupTransactionsByDate(_ transactions: [NormalizedTransaction]) -> [GroupedTransactionSection] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        let monthYearFormatter = DateFormatter()
        monthYearFormatter.dateFormat = "MMMM yyyy"

        var grouped: [String: [NormalizedTransaction]] = [:]

        for transaction in transactions {
            let key = dateFormatter.string(from: transaction.date)
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(transaction)
        }

        var sections: [GroupedTransactionSection] = []

        for (dateKey, txns) in grouped.sorted(by: { $0.key > $1.key }) {
            if let date = dateFormatter.date(from: dateKey) {
                let section = GroupedTransactionSection(
                    date: dateKey,
                    displayDate: displayFormatter.string(from: date),
                    transactions: txns.sorted { $0.amount > $1.amount },
                    totalAmount: txns.reduce(0) { $0 + $1.amount }
                )
                sections.append(section)
            }
        }

        return sections
    }

    // MARK: - Cache Status

    var hasExpenses: Bool {
        return !expenses.isEmpty
    }

    var hasIncomes: Bool {
        return !incomes.isEmpty
    }

    var isCachePopulated: Bool {
        return hasExpenses || hasIncomes
    }

    func getTransactionSummary() -> String {
        let expenseTotal = expenses.reduce(0) { $0 + $1.amount }
        let incomeTotal = incomes.reduce(0) { $0 + $1.amount }
        return "Expenses: \(expenses.count) (Total: $\(String(format: "%.2f", expenseTotal)))\nIncomes: \(incomes.count) (Total: $\(String(format: "%.2f", incomeTotal)))"
    }

    var selectedPage: (id: String, title: String)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let data = cache["selectedPage"] as? [String: String] else { return nil }
            return (id: data["id"] ?? "", title: data["title"] ?? "")
        }
        set {
            lock.lock()
            cache["selectedPage"] = ["id": newValue?.id ?? "", "title": newValue?.title ?? ""]
            lock.unlock()
        }
    }

    var databaseMappings: [String: DatabaseMappingData] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["databaseMappings"] as? [String: DatabaseMappingData] ?? [:]
        }
        set {
            lock.lock()
            cache["databaseMappings"] = newValue
            lock.unlock()
        }
    }

    func setMapping(for databaseId: String, data: DatabaseMappingData) {
        lock.lock()
        var mappings = cache["databaseMappings"] as? [String: DatabaseMappingData] ?? [:]
        mappings[databaseId] = data
        cache["databaseMappings"] = mappings
        lock.unlock()
    }

    func getMapping(for databaseId: String) -> DatabaseMappingData? {
        lock.lock()
        defer { lock.unlock() }
        return (cache["databaseMappings"] as? [String: DatabaseMappingData])?[databaseId]
    }

    var categoryValues: [String: [CategoryValue]] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["categoryValues"] as? [String: [CategoryValue]] ?? [:]
        }
        set {
            lock.lock()
            cache["categoryValues"] = newValue
            lock.unlock()
        }
    }

    func setCategories(_ categories: [CategoryValue], for databaseId: String) {
        lock.lock()
        var allCategories = cache["categoryValues"] as? [String: [CategoryValue]] ?? [:]
        allCategories[databaseId] = categories
        cache["categoryValues"] = allCategories
        lock.unlock()
    }

    func getCategories(for databaseId: String) -> [CategoryValue] {
        lock.lock()
        defer { lock.unlock() }
        return (cache["categoryValues"] as? [String: [CategoryValue]])?[databaseId] ?? []
    }

    var hasSetupComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        let mappings = cache["databaseMappings"] as? [String: DatabaseMappingData] ?? [:]
        return !mappings.isEmpty
    }

    // MARK: - Targeted Cache Updates (for edit/delete)

    func replaceExpense(_ transaction: NormalizedTransaction) {
        lock.lock()
        var all = cache["expenses"] as? [NormalizedTransaction] ?? []
        if let idx = all.firstIndex(where: { $0.id == transaction.id }) {
            all[idx] = transaction
            cache["expenses"] = all
        }
        lock.unlock()
        self.expenseSections = groupTransactionsByDate(all)
    }

    func replaceIncome(_ transaction: NormalizedTransaction) {
        lock.lock()
        var all = cache["incomes"] as? [NormalizedTransaction] ?? []
        if let idx = all.firstIndex(where: { $0.id == transaction.id }) {
            all[idx] = transaction
            cache["incomes"] = all
        }
        lock.unlock()
        self.incomeSections = groupTransactionsByDate(all)
    }

    func removeExpense(byPageId pageId: String) {
        lock.lock()
        var all = cache["expenses"] as? [NormalizedTransaction] ?? []
        all.removeAll(where: { $0.id == pageId })
        cache["expenses"] = all
        lock.unlock()
        self.expenseSections = groupTransactionsByDate(all)
    }

    func removeIncome(byPageId pageId: String) {
        lock.lock()
        var all = cache["incomes"] as? [NormalizedTransaction] ?? []
        all.removeAll(where: { $0.id == pageId })
        cache["incomes"] = all
        lock.unlock()
        self.incomeSections = groupTransactionsByDate(all)
    }

    func clearSession() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    func clearAll() {
        clearSession()
    }

    private(set) var lastLoadedMonth: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cache["lastLoadedMonth"] as? Date
        }
        set {
            lock.lock()
            cache["lastLoadedMonth"] = newValue
            lock.unlock()
        }
    }

    func setLastLoadedMonth(_ date: Date) {
        lastLoadedMonth = date
    }

    var setupSummary: String {
        lock.lock()
        let mappings = cache["databaseMappings"] as? [String: DatabaseMappingData] ?? [:]
        let categories = cache["categoryValues"] as? [String: [CategoryValue]] ?? [:]
        lock.unlock()

        var summary = "Session Cache:\n"
        summary += "- Databases configured: \(mappings.count)\n"

        let expenseCount = mappings.values.filter { $0.role == .expense }.count
        let incomeCount = mappings.values.filter { $0.role == .income }.count
        summary += "- Expense DBs: \(expenseCount)\n"
        summary += "- Income DBs: \(incomeCount)\n"

        var totalCategories = 0
        for (_, cats) in categories {
            totalCategories += cats.count
        }
        summary += "- Total categories: \(totalCategories)\n"

        return summary
    }

    // MARK: - Discovered Databases Cache

    var discoveredDatabases: [DiscoveredDatabase] {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let dbCache = cache["discoveredDatabases"] as? [String: [String: String]] else { return [] }
            return dbCache.compactMap { id, data in
                guard let title = data["__title__"] else { return nil }
                return DiscoveredDatabase(id: id, title: title, parentPageId: "", properties: [:], assignedRole: nil)
            }
        }
    }

    func saveDiscoveredDatabases(_ databases: [DiscoveredDatabase]) {
        lock.lock()
        var dbCache: [String: [String: String]] = [:]  // [dbId: [pageId: title]]
        for db in databases {
            dbCache[db.id] = ["__title__": db.title, "__properties__": ""]
        }
        cache["discoveredDatabases"] = dbCache
        lock.unlock()
        print("[SessionCache] Saved \(databases.count) discovered databases")
    }

    func saveRelationTargetData(databaseId: String, rows: [NotionPage]) {
        lock.lock()
        var relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        var lookup: [String: String] = [:]
        for row in rows {
            let title = extractTitle(from: row)
            lookup[row.id] = title
        }
        relationData[databaseId] = lookup
        cache["relationData"] = relationData
        lock.unlock()
        print("[SessionCache] Cached \(lookup.count) rows for relation DB: \(databaseId)")
    }

    func saveRelationTargetData(databaseId: String, lookup: [String: String]) {
        lock.lock()
        var relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        relationData[databaseId] = lookup
        cache["relationData"] = relationData
        lock.unlock()
        print("[SessionCache] Cached \(lookup.count) items for relation DB: \(databaseId) via lookup")
    }

    private func extractTitle(from page: NotionPage) -> String {
        return page.title
    }

    func extractDatabaseId(from page: NotionPage) -> String? {
        return page.parent.databaseId
    }

    func getRelationTargetData(databaseId: String) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        let relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        if let data = relationData[databaseId] {
            print("[SessionCache] Found cached data for relation DB: \(databaseId) with \(data.count) items")
            return data
        }
        print("[SessionCache] No cached data for relation DB: \(databaseId)")
        return nil
    }

    // Searches across all cached relation target databases for page ID → title matches.
    // Use as fallback when the caller doesn't know which target DB a relation belongs to
    // (e.g., month classification in TransactionDetailViewController).
    func resolveRelationTitles(pageIds: [String]) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        for (_, lookup) in relationData {
            let titles = pageIds.compactMap { lookup[$0] }.filter { !$0.isEmpty }
            if !titles.isEmpty {
                return titles
            }
        }
        return []
    }

    func isRelationTargetCached(databaseId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        return relationData[databaseId] != nil
    }

    // MARK: - Category Lookup (for relation-based categories)

    func setCategoryLookup(for dataSourceId: String, lookup: [String: String]) {
        lock.lock()
        var categoryLookups = cache["categoryLookups"] as? [String: [String: String]] ?? [:]
        categoryLookups[dataSourceId] = lookup
        cache["categoryLookups"] = categoryLookups
        lock.unlock()
        print("[SessionCache] Cached \(lookup.count) category entries for data source: \(dataSourceId)")
    }

    func getCategoryLookup(for dataSourceId: String) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        let categoryLookups = cache["categoryLookups"] as? [String: [String: String]] ?? [:]
        if let lookup = categoryLookups[dataSourceId] {
            print("[SessionCache] Cache HIT for category lookup: \(dataSourceId) with \(lookup.count) entries")
            return lookup
        }
        print("[SessionCache] Cache MISS for category lookup: \(dataSourceId)")
        return nil
    }

    // MARK: - Database Schema Cache (for filter UI)

    func getDatabaseSchema(databaseId: String) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        let schemas = cache["databaseSchemas"] as? [String: [String: String]] ?? [:]
        return schemas[databaseId]
    }

    func saveDatabaseSchema(databaseId: String, schema: [String: String]) {
        lock.lock()
        var schemas = cache["databaseSchemas"] as? [String: [String: String]] ?? [:]
        schemas[databaseId] = schema
        cache["databaseSchemas"] = schemas
        lock.unlock()
        print("[SessionCache] Saved schema for database: \(databaseId)")
    }

    func getSelectOptions(databaseId: String) -> [String: [String]]? {
        lock.lock()
        defer { lock.unlock() }
        let options = cache["selectOptions"] as? [String: [String: [String]]] ?? [:]
        return options[databaseId]
    }

    func saveSelectOptions(databaseId: String, options: [String: [String]]) {
        lock.lock()
        var allOptions = cache["selectOptions"] as? [String: [String: [String]]] ?? [:]
        allOptions[databaseId] = options
        cache["selectOptions"] = allOptions
        lock.unlock()
        print("[SessionCache] Saved select options for database: \(databaseId)")
    }

    // MARK: - Relation Target DB IDs Cache (source property → target database)

    func saveRelationTargetDbIds(databaseId: String, mapping: [String: String]) {
        lock.lock()
        var allMapping = cache["relationTargetDbIds"] as? [String: [String: String]] ?? [:]
        allMapping[databaseId] = mapping
        cache["relationTargetDbIds"] = allMapping
        lock.unlock()
        print("[SessionCache] Saved \(mapping.count) relation target DB IDs for: \(databaseId)")
    }

    func getAllRelationTargetDbIds(databaseId: String) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        let allMapping = cache["relationTargetDbIds"] as? [String: [String: String]] ?? [:]
        return allMapping[databaseId]
    }

    func deleteRelationTargetData(databaseId: String) {
        lock.lock()
        var relationData = cache["relationData"] as? [String: [String: String]] ?? [:]
        relationData.removeValue(forKey: databaseId)
        cache["relationData"] = relationData
        lock.unlock()
        print("[SessionCache] Deleted stale relation data for: \(databaseId)")
    }

    func clearCategoryLookup(for dataSourceId: String) {
        lock.lock()
        var categoryLookups = cache["categoryLookups"] as? [String: [String: String]] ?? [:]
        categoryLookups.removeValue(forKey: dataSourceId)
        cache["categoryLookups"] = categoryLookups
        lock.unlock()
        print("[SessionCache] Cleared stale category lookup for: \(dataSourceId)")
    }
}