//
//  SetupStateManager.swift
//  Notra
//

import Foundation

enum SetupStep: String {
    case tokenEntry = "TokenEntry"
    case pagePicker = "PagePicker"
    case databaseRoleAssignment = "DatabaseRoleAssignment"
    case columnMapping = "ColumnMapping"
    case dashboard = "Dashboard"
}

final class SetupStateManager {
    static let shared = SetupStateManager()

    private init() {}

    func hasToken() -> Bool {
        let exists = UserDefaultsManager.shared.notionToken != nil
        print("[SetupState] token exists: \(exists)")
        return exists
    }

    func hasSelectedPage() -> Bool {
        let exists = UserDefaultsManager.shared.selectedPageId != nil
        print("[SetupState] selected page exists: \(exists)")
        return exists
    }

    func hasDatabaseRoles() -> Bool {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        let hasRoles = !mappings.isEmpty
        print("[SetupState] database roles exist: \(hasRoles)")
        return hasRoles
    }

    func hasExpenseMapping() -> Bool {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        let hasExpense = mappings.values.contains { $0.role == .expense && $0.columnMapping != nil }
        print("[SetupState] expense mapping exists: \(hasExpense)")
        return hasExpense
    }

    func hasIncomeMapping() -> Bool {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        let hasIncome = mappings.values.contains { $0.role == .income && $0.columnMapping != nil }
        print("[SetupState] income mapping exists: \(hasIncome)")
        return hasIncome
    }

    func isSetupComplete() -> Bool {
        return hasToken() && hasSelectedPage() && hasDatabaseRoles() && hasExpenseMapping() && hasIncomeMapping()
    }

    func nextRequiredScreen() -> SetupStep {
        print("[SetupState] determining next startup screen...")

        if !hasToken() {
            print("[SetupState] routing to TokenEntry")
            return .tokenEntry
        }

        if !hasSelectedPage() {
            print("[SetupState] routing to PagePicker")
            return .pagePicker
        }

        if !hasDatabaseRoles() {
            print("[SetupState] routing to DatabaseRoleAssignment")
            return .databaseRoleAssignment
        }

        if !hasExpenseMapping() || !hasIncomeMapping() {
            print("[SetupState] routing to ColumnMapping")
            return .columnMapping
        }

        print("[SetupState] routing to Dashboard")
        return .dashboard
    }

    func resetSetup() {
        print("[SetupState] resetting setup state...")
        UserDefaultsManager.shared.notionToken = nil
        UserDefaultsManager.shared.selectedPageId = nil
        UserDefaultsManager.shared.selectedPageTitle = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.databaseMappings)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.columnMappings)
        SessionCacheManager.shared.clearAll()
        print("[SetupState] setup reset complete")
    }
}