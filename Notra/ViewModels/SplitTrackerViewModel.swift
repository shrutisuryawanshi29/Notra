import Foundation

protocol SplitTrackerViewModelDelegate: AnyObject {
    func didUpdateData()
    func didStartLoading()
    func didFinishLoading()
    func didFailUpdate(_ error: String)
}

enum SplitTrackerFilter: String, CaseIterable {
    case pending = "Pending"
    case settled = "Settled"
    case all = "All"

    static let `default`: SplitTrackerFilter = .pending
}

final class SplitTrackerViewModel {

    weak var delegate: SplitTrackerViewModelDelegate?

    private(set) var personGroups: [SplitTrackerPersonGroup] = []
    private(set) var totalPendingOwed: Double = 0
    private(set) var totalSettled: Double = 0
    private(set) var isLoading = false
    private(set) var isEmpty = true

    var activeFilter: SplitTrackerFilter = .default {
        didSet { applyFilter() }
    }

    private var allGroups: [SplitTrackerPersonGroup] = []
    private var filteredGroups: [SplitTrackerPersonGroup] = []

    private let cache = SessionCacheManager.shared

    func loadSplitTransactions() {
        isLoading = true
        delegate?.didStartLoading()

        let expenses = cache.allExpenses
        let splitExpenses = expenses.filter { $0.isSplit && ($0.splitMetadata?.theyOwe ?? 0) > 0 }

        let groups = buildGroups(from: splitExpenses)
        allGroups = groups
        applyFilter()
        isLoading = false
        delegate?.didFinishLoading()
    }

    private func buildGroups(from transactions: [NormalizedTransaction]) -> [SplitTrackerPersonGroup] {
        var personMap: [String: (name: String, entries: [SplitTrackerEntry])] = [:]

        for tx in transactions {
            guard let split = tx.splitMetadata else { continue }
            let participants = split.participants ?? []

            if !participants.isEmpty {
                // Version 2: use participant array
                for p in participants {
                    let status = SettlementStatus(rawValue: p.status ?? "pending") ?? .pending
                    let entry = SplitTrackerEntry(
                        transactionId: tx.id,
                        transactionTitle: tx.title,
                        date: tx.date,
                        category: tx.category,
                        amountOwed: p.owes,
                        status: status,
                        settledAt: p.settledAt,
                        participantId: p.id,
                        splitMetadata: split,
                        transaction: tx
                    )
                    let key = p.id
                    if var existing = personMap[key] {
                        existing.entries.append(entry)
                        personMap[key] = existing
                    } else {
                        personMap[key] = (name: p.name, entries: [entry])
                    }
                }
            } else {
                // Fallback: use splitWith or generic name
                let personId = "unknown_\(tx.id)"
                let personName = split.splitWith ?? "Someone"
                let status: SettlementStatus = .pending
                let entry = SplitTrackerEntry(
                    transactionId: tx.id,
                    transactionTitle: tx.title,
                    date: tx.date,
                    category: tx.category,
                    amountOwed: split.theyOwe,
                    status: status,
                    settledAt: nil,
                    participantId: personId,
                    splitMetadata: split,
                    transaction: tx
                )
                if var existing = personMap[personId] {
                    existing.entries.append(entry)
                    personMap[personId] = existing
                } else {
                    personMap[personId] = (name: personName, entries: [entry])
                }
            }
        }

        return personMap.values.map { data in
            let pending = data.entries.filter { $0.status == .pending }.reduce(0) { $0 + $1.amountOwed }
            let settled = data.entries.filter { $0.status == .settled }.reduce(0) { $0 + $1.amountOwed }
            return SplitTrackerPersonGroup(
                personId: data.entries.first?.participantId ?? "",
                personName: data.name,
                pendingTotal: pending,
                settledTotal: settled,
                entries: data.entries
            )
        }.sorted { $0.personName.lowercased() < $1.personName.lowercased() }
    }

    private func applyFilter() {
        switch activeFilter {
        case .pending:
            filteredGroups = allGroups.map { group in
                let pendingEntries = group.entries.filter { $0.status == .pending }
                return SplitTrackerPersonGroup(
                    personId: group.personId,
                    personName: group.personName,
                    pendingTotal: pendingEntries.reduce(0) { $0 + $1.amountOwed },
                    settledTotal: 0,
                    entries: pendingEntries
                )
            }.filter { !$0.entries.isEmpty }
        case .settled:
            filteredGroups = allGroups.map { group in
                let settledEntries = group.entries.filter { $0.status == .settled }
                return SplitTrackerPersonGroup(
                    personId: group.personId,
                    personName: group.personName,
                    pendingTotal: 0,
                    settledTotal: settledEntries.reduce(0) { $0 + $1.amountOwed },
                    entries: settledEntries
                )
            }.filter { !$0.entries.isEmpty }
        case .all:
            filteredGroups = allGroups
        }

        personGroups = filteredGroups
        totalPendingOwed = filteredGroups.reduce(0) { $0 + $1.pendingTotal }
        totalSettled = filteredGroups.reduce(0) { $0 + $1.settledTotal }
        isEmpty = filteredGroups.isEmpty
    }

    func updateSettlementStatus(entry: SplitTrackerEntry, newStatus: SettlementStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let split = entry.transaction.splitMetadata,
              var participants = split.participants,
              let idx = participants.firstIndex(where: { $0.id == entry.participantId }) else {
            completion(.failure(SplitTrackerError.noParticipantFound))
            return
        }

        participants[idx].settlementStatus = newStatus
        if newStatus == .settled {
            let formatter = ISO8601DateFormatter()
            participants[idx].settledAt = formatter.string(from: Date())
        } else {
            participants[idx].settledAt = nil
        }

        guard let jsonString = split.buildUpdatedJSON(updatedParticipants: participants) else {
            completion(.failure(SplitTrackerError.jsonBuildFailed))
            return
        }

        // Build PATCH payload
        guard let columnMapping = getAppMetadataColumn(for: entry.transaction.databaseId) else {
            completion(.failure(SplitTrackerError.noMetadataColumn))
            return
        }

        guard let token = UserDefaultsManager.shared.notionToken else {
            completion(.failure(SplitTrackerError.noToken))
            return
        }

        var value = DynamicFormValue(propertyName: columnMapping, propertyType: .richText)
        value.stringValue = jsonString

        TransactionInsertService.shared.updateTransaction(
            pageId: entry.transactionId,
            values: [value],
            token: token
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let page):
                    // Update local cache
                    var updatedTx = entry.transaction
                    var updatedSplit = split
                    if let pIdx = updatedSplit.participants?.firstIndex(where: { $0.id == entry.participantId }) {
                        updatedSplit.participants?[pIdx] = participants[idx]
                    }
                    updatedTx = NormalizedTransaction(
                        id: updatedTx.id,
                        title: updatedTx.title,
                        amount: updatedTx.amount,
                        paidAmount: updatedTx.paidAmount,
                        category: updatedTx.category,
                        date: updatedTx.date,
                        databaseId: updatedTx.databaseId,
                        databaseRole: updatedTx.databaseRole,
                        rawProperties: page.properties,
                        splitMetadata: updatedSplit
                    )
                    SessionCacheManager.shared.replaceExpense(updatedTx)
                    self?.loadSplitTransactions()
                    completion(.success(()))
                case .failure(let error):
                    self?.delegate?.didFailUpdate(error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }
    }

    private func getAppMetadataColumn(for databaseId: String) -> String? {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        return mappings[databaseId]?.columnMapping?.expenseAppMetadataProperty
    }
}

enum SplitTrackerError: LocalizedError {
    case noParticipantFound
    case jsonBuildFailed
    case noMetadataColumn
    case noToken

    var errorDescription: String? {
        switch self {
        case .noParticipantFound: return "Could not find participant in split metadata."
        case .jsonBuildFailed: return "Could not build updated split metadata."
        case .noMetadataColumn: return "No split metadata column configured for this database."
        case .noToken: return "Notion token not found."
        }
    }
}
