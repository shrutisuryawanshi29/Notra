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

    func clearSession() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
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
}