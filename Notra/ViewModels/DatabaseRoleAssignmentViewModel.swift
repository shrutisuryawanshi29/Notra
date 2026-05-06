//
//  DatabaseRoleAssignmentViewModel.swift
//  Notra
//

import Foundation

protocol DatabaseRoleAssignmentViewModelDelegate: AnyObject {
    func roleAssignmentDidStartLoading()
    func roleAssignmentDidFinishLoading(databases: [DiscoveredDatabase])
    func roleAssignmentDidFail(_ error: String)
}

final class DatabaseRoleAssignmentViewModel {
    weak var delegate: DatabaseRoleAssignmentViewModelDelegate?

    private(set) var databases: [DiscoveredDatabase] = []
    private var roleAssignments: [String: DatabaseRole] = [:]
    private let debug = true

    func loadDatabases() {
        guard let token = UserDefaultsManager.shared.notionToken,
              let pageId = UserDefaultsManager.shared.selectedPageId else {
            if debug { print("[RoleAssignmentVM] No token or page selected") }
            delegate?.roleAssignmentDidFail("No page selected")
            return
        }

        if debug { print("[RoleAssignmentVM] Loading databases for page: \(pageId)") }
        delegate?.roleAssignmentDidStartLoading()

        DatabaseDiscoveryService.shared.discoverDatabases(from: pageId, token: token) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let dbs):
                self.databases = dbs
                if self.debug { print("[RoleAssignmentVM] Got \(dbs.count) databases") }
                DispatchQueue.main.async {
                    self.delegate?.roleAssignmentDidFinishLoading(databases: dbs)
                }

            case .failure(let error):
                if self.debug { print("[RoleAssignmentVM] Error: \(error)") }
                DispatchQueue.main.async {
                    self.delegate?.roleAssignmentDidFail(error.localizedDescription)
                }
            }
        }
    }

    func assignRole(_ role: DatabaseRole, to index: Int) {
        guard index >= 0 && index < databases.count else { return }
        databases[index].assignedRole = role
        roleAssignments[databases[index].id] = role
    }

    func getRole(for index: Int) -> DatabaseRole {
        guard index >= 0 && index < databases.count else { return .ignore }
        return databases[index].assignedRole ?? .ignore
    }

    func getDatabasesWithRole(_ role: DatabaseRole) -> [DiscoveredDatabase] {
        return databases.filter { $0.assignedRole == role }
    }

    func saveMappings() {
        var mappingData: [String: DatabaseMappingData] = [:]

        for db in databases {
            guard let role = db.assignedRole, role != .ignore else { continue }

            let mapping = DatabaseMappingData(
                databaseId: db.id,
                databaseTitle: db.title,
                role: role,
                columnMapping: nil,
                categoryType: nil,
                categoryValuesJSON: nil)

            mappingData[db.id] = mapping
        }

        ColumnMappingService.shared.saveDatabaseMappings(mappingData)
    }
}