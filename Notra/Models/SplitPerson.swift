import Foundation

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

    @discardableResult
    func addPerson(name: String) -> SplitPerson {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { fatalError("Name cannot be empty") }
        let person = SplitPerson(id: UUID().uuidString, name: trimmed)
        people.append(person)
        save()
        return person
    }

    func deletePerson(id: String) {
        people.removeAll { $0.id == id }
        save()
    }

    func updatePersonName(id: String, name: String) {
        guard let idx = people.firstIndex(where: { $0.id == id }) else { return }
        people[idx].name = name.trimmingCharacters(in: .whitespaces)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SplitPerson].self, from: data) else { return }
        people = decoded
    }
}
