import Foundation

func stablePersonId(from name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = trimmed.lowercased()
    let withoutAccents = lowered.folding(options: .diacriticInsensitive, locale: nil)
    let noUnsupported = withoutAccents.replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
    let spacesToHyphens = noUnsupported.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    let collapsedHyphens = spacesToHyphens.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
    return collapsedHyphens.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

struct SplitPerson: Codable, Identifiable, Equatable {
    let id: String
    var name: String
}

final class SplitPeopleStore {
    static let shared = SplitPeopleStore()
    private let defaultsKey = "notraSplitPeople"

    private var people: [SplitPerson] = []

    private init() { load() }

    func getPeople() -> [SplitPerson] {
        people
    }

    func getPersonByStableId(_ stableId: String) -> SplitPerson? {
        people.first(where: { $0.id == stableId })
    }

    @discardableResult
    func addPerson(name: String) -> SplitPerson {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { fatalError("Name cannot be empty") }
        let stableId = stablePersonId(from: trimmed)
        guard !stableId.isEmpty else { fatalError("Name must contain valid characters") }
        if let existing = people.first(where: { $0.id == stableId }) {
            return existing
        }
        let person = SplitPerson(id: stableId, name: trimmed)
        people.append(person)
        save()
        return person
    }

    func deletePerson(id: String) {
        people.removeAll { $0.id == id }
        save()
    }

    func updatePersonName(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newId = stablePersonId(from: trimmed)
        guard !newId.isEmpty else { return }
        people.removeAll { $0.id == id }
        if !people.contains(where: { $0.id == newId }) {
            let person = SplitPerson(id: newId, name: trimmed)
            people.append(person)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SplitPerson].self, from: data) else { return }
        var migrated: [SplitPerson] = []
        var seenIds = Set<String>()
        for person in decoded {
            let stableId = stablePersonId(from: person.name)
            guard !stableId.isEmpty else { continue }
            guard !seenIds.contains(stableId) else { continue }
            let migratedPerson = SplitPerson(id: stableId, name: person.name)
            migrated.append(migratedPerson)
            seenIds.insert(stableId)
        }
        people = migrated
        if people != decoded {
            save()
        }
    }
}
