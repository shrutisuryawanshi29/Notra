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
        didSet {
            print("[SplitTracker] main filter changed to=\(activeFilter.rawValue)")
            applyFilter()
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didUpdateData()
            }
        }
    }

    private(set) var allGroups: [SplitTrackerPersonGroup] = []
    private var filteredGroups: [SplitTrackerPersonGroup] = []

    private let cache = SessionCacheManager.shared

    func loadSplitTransactions() {
        isLoading = true
        print("[SplitTracker] reload triggered after transaction update")
        delegate?.didStartLoading()

        let expenses = cache.allExpenses
        let splitExpenses = expenses.filter { $0.isSplit }

        let groups = buildGroups(from: splitExpenses)
        allGroups = groups
        let allPending = allGroups.reduce(0) { $0 + $1.pendingTotal }
        let allSettled = allGroups.reduce(0) { $0 + $1.settledTotal }
        print("[SplitTracker] rebuild allEntries=\(allGroups.reduce(0) { $0 + $1.entries.count }), pending=\(allPending), settled=\(allSettled)")
        applyFilter()

        print("[SplitTracker] rebuilt groups total=\(allGroups.count), pendingTotal=\(allPending), settledTotal=\(allSettled)")
        for g in personGroups {
            print("[SplitTracker] group personId=\(g.personId), displayName=\(g.personName), pendingTotal=\(g.pendingTotal), settledTotal=\(g.settledTotal)")
        }
        isLoading = false
        delegate?.didFinishLoading()
    }

    private func resolvedDisplayName(from participant: SplitParticipant) -> String {
        let trimmed = participant.name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != "Someone" {
            return trimmed
        }
        if let person = SplitPeopleStore.shared.getPersonByStableId(participant.id) {
            print("[SplitTracker] resolvedDisplayName=\(person.name) via SplitPeopleStore for id=\(participant.id)")
            return person.name
        }
        let readable = stableIdToReadableName(participant.id)
        if !readable.isEmpty {
            print("[SplitTracker] resolvedDisplayName=\(readable) via id conversion for id=\(participant.id)")
            return readable
        }
        return "Unknown person"
    }

    private func stableIdToReadableName(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("_") else { return "" }
        return trimmed
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func buildGroups(from transactions: [NormalizedTransaction]) -> [SplitTrackerPersonGroup] {
        var personMap: [String: (name: String, entries: [SplitTrackerEntry])] = [:]
        print("[SplitTracker] building groups from \(transactions.count) split transactions")

        for tx in transactions {
            guard let split = tx.splitMetadata else { continue }
            let participants = split.participants ?? []

            if !participants.isEmpty {
                for p in participants {
                    let status = SettlementStatus(rawValue: p.status ?? "pending") ?? .pending
                    let nameBased = stablePersonId(from: p.name)
                    let stableKey = nameBased.isEmpty ? p.id : nameBased
                    let displayName = resolvedDisplayName(from: p)
                    print("[SplitTracker] group personId=\(stableKey), displayName=\(displayName)")
                    print("[SplitTracker] entry title=\(tx.title), participantName=\(p.name), participantId=\(p.id), owes=\(p.owes)")
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
                    if var existing = personMap[stableKey] {
                        existing.entries.append(entry)
                        personMap[stableKey] = existing
                    } else {
                        personMap[stableKey] = (name: displayName, entries: [entry])
                    }
                }
            } else {
                let personId = "unknown_\(tx.id)"
                let personName = split.splitWith ?? "Unknown person"
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

        let allEntries = personMap.values.flatMap { $0.entries }
        let parsedPending = allEntries.filter { $0.status == .pending }.count
        let parsedSettled = allEntries.filter { $0.status == .settled }.count
        print("[SplitTracker] parsed entries total=\(allEntries.count)")
        print("[SplitTracker] parsed pending=\(parsedPending)")
        print("[SplitTracker] parsed settled=\(parsedSettled)")

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
        print("[SplitTracker] selectedFilter=\(activeFilter.rawValue)")
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
        print("[SplitTracker] summary pendingTotal=\(totalPendingOwed), settledTotal=\(totalSettled), allTotal=\(totalPendingOwed + totalSettled)")
        print("[SplitTracker] visibleGroups count=\(filteredGroups.count)")
        for g in filteredGroups {
            print("[SplitTracker] group person=\(g.personName), pendingTotal=\(g.pendingTotal), settledTotal=\(g.settledTotal), allTotal=\(g.totalOwed)")
        }
    }

    func updateSettlementStatus(entry: SplitTrackerEntry, newStatus: SettlementStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let split = entry.transaction.splitMetadata,
              var participants = split.participants else {
            completion(.failure(SplitTrackerError.noParticipantFound))
            return
        }
        let idx = participants.firstIndex(where: { $0.id == entry.participantId })
            ?? participants.firstIndex(where: { stablePersonId(from: $0.name) == entry.participantId })
        guard let idx = idx else {
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
                    let cacheIdx = updatedSplit.participants?.firstIndex(where: { $0.id == entry.participantId })
                        ?? updatedSplit.participants?.firstIndex(where: { stablePersonId(from: $0.name) == entry.participantId })
                    if let pIdx = cacheIdx {
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
