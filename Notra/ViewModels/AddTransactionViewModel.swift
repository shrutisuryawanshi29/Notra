//
//  AddTransactionViewModel.swift
//  Notra
//

import Foundation

protocol AddTransactionViewModelDelegate: AnyObject {
    func didLoadFields(_ fields: [DynamicFormField])
    func didFailToLoadFields(error: String)
    func didLoadRelationOptions(for propertyName: String, options: [(id: String, title: String)])
    func didFailToLoadRelationOptions(for propertyName: String, error: String)
    func didStartSaving()
    func didSaveSuccessfully()
    func didFailToSave(error: String)
    func didValidateForm(isValid: Bool, missingFields: [String])
}

final class AddTransactionViewModel {
    weak var delegate: AddTransactionViewModelDelegate?

    private(set) var selectedRole: DatabaseRole = .expense
    private(set) var fields: [DynamicFormField] = []
    private(set) var fieldValues: [String: DynamicFormValue] = [:]
    private(set) var relationOptions: [String: [(id: String, title: String)]] = [:]
    private(set) var isFetchingFields = false

    private var mappings: [String: DatabaseMappingData] = [:]
    private var token: String {
        return UserDefaultsManager.shared.notionToken ?? ""
    }

    var targetDatabaseId: String? {
        return mappings.values.first { $0.role == selectedRole }?.databaseId
    }

    var targetDatabaseMapping: DatabaseMappingData? {
        return mappings.values.first { $0.role == selectedRole }
    }

    init() {
        loadMappings()
    }

    private func loadMappings() {
        mappings = ColumnMappingService.shared.loadDatabaseMappings()
        print("[AddTransactionVM] Loaded \(mappings.count) database mappings")
    }

    func switchMode(to role: DatabaseRole) {
        selectedRole = role
        print("[AddTransactionVM] Switched to \(role.displayName) mode")
        generateFields()
    }

    func generateFields() {
        print("[AddTransactionVM] Generating fields for \(selectedRole.displayName) mode")

        guard let mapping = targetDatabaseMapping else {
            print("[AddTransactionVM] No mapping found for \(selectedRole.displayName)")
            delegate?.didFailToLoadFields(error: "No \(selectedRole.displayName) database configured.\nGo to Settings → Database Mapping to configure.")
            return
        }

        let databaseId = mapping.databaseId
        let columnMapping = mapping.columnMapping

        print("[AddTransactionVM] Target database: \(mapping.databaseTitle) (ID: \(databaseId))")

        isFetchingFields = true

        NotionService.shared.fetchDatabaseSchema(databaseId: databaseId, token: token) { [weak self] result in
            guard let self = self else { return }
            self.isFetchingFields = false

            switch result {
            case .success(let properties):
                self.buildFields(from: properties, columnMapping: columnMapping)

            case .failure(let error):
                print("[AddTransactionVM] Failed to fetch schema: \(error)")
                self.delegate?.didFailToLoadFields(error: "Could not load database schema: \(error.localizedDescription)")
            }
        }
    }

    private func buildFields(from properties: [String: Any], columnMapping: ColumnMapping?) {
        print("[AddTransactionVM] Building fields from \(properties.count) properties...")

        var generatedFields: [DynamicFormField] = []
        fieldValues = [:]

        let sortedProps = properties.sorted { $0.key < $1.key }

        for (propName, propValue) in sortedProps {
            guard let prop = propValue as? [String: Any],
                  let propType = prop["type"] as? String else { continue }

            if NotionPropertyType.isReadOnly(propType) {
                print("[AddTransactionVM] Skipping read-only property: \(propName) (\(propType))")
                continue
            }

            guard let notionType = NotionPropertyType.from(string: propType) else {
                print("[AddTransactionVM] Unsupported property type: \(propName) (\(propType))")
                continue
            }

            var options: [SelectOption] = []

            if notionType == .select || notionType == .multiSelect {
                let configKey = notionType == .select ? "select" : "multi_select"
                if let config = prop[configKey] as? [String: Any],
                   let configOptions = config["options"] as? [[String: Any]] {
                    options = configOptions.compactMap { dict in
                        guard let name = dict["name"] as? String else { return nil }
                        return SelectOption(name: name)
                    }
                }
            }

            var relationDsId: String? = nil
            if notionType == .relation, let relationConfig = prop["relation"] as? [String: Any] {
                relationDsId = relationConfig["database_id"] as? String
                if relationDsId == nil {
                    relationDsId = relationConfig["data_source_id"] as? String
                }
                print("[AddTransactionVM] Relation '\(propName)' -> ds:\(relationConfig["data_source_id"] as? String ?? "nil") db:\(relationConfig["database_id"] as? String ?? "nil") using:\(relationDsId ?? "nil")")
            }

            let isMapped = isPropertyMapped(propName, columnMapping: columnMapping)
            let mappedRole = isMapped ? getMappedRole(propName, columnMapping: columnMapping) : nil

            let field = DynamicFormField(
                propertyName: propName,
                propertyType: notionType,
                isRequired: isMapped,
                isMappedCoreField: isMapped,
                mappedRole: mappedRole,
                options: options,
                relationDataSourceId: relationDsId
            )

            if isMapped {
                print("[AddTransactionVM] Mapped core field: \(propName) (\(notionType.rawValue)) = \(mappedRole ?? "")")
            }

            generatedFields.append(field)

            var formValue = DynamicFormValue(propertyName: propName, propertyType: notionType)
            if notionType == .date {
                formValue.dateValue = Date()
            }
            fieldValues[propName] = formValue
        }

        generatedFields = sortFieldsByPriority(generatedFields, columnMapping: columnMapping)

        fields = generatedFields

        print("[AddTransactionVM] Total properties found: \(properties.count)")
        print("[AddTransactionVM] Writable fields generated: \(fields.count)")
        print("[AddTransactionVM] Writable fields: \(fields.map { "\($0.propertyName)(\($0.propertyType.rawValue))" }.joined(separator: ", "))")

        delegate?.didLoadFields(fields)

        for field in fields where field.propertyType == .relation {
            loadRelationOptions(for: field)
        }
    }

    private func isPropertyMapped(_ propName: String, columnMapping: ColumnMapping?) -> Bool {
        guard let mapping = columnMapping else { return false }
        return propName == mapping.titleColumn ||
               propName == mapping.amountColumn ||
               propName == mapping.categoryColumn ||
               propName == mapping.dateColumn
    }

    private func getMappedRole(_ propName: String, columnMapping: ColumnMapping?) -> String? {
        guard let mapping = columnMapping else { return nil }
        if propName == mapping.titleColumn { return "Title" }
        if propName == mapping.amountColumn { return "Amount" }
        if propName == mapping.categoryColumn { return "Category" }
        if propName == mapping.dateColumn { return "Date" }
        return nil
    }

    private func sortFieldsByPriority(_ fields: [DynamicFormField], columnMapping: ColumnMapping?) -> [DynamicFormField] {
        guard let mapping = columnMapping else { return fields }

        let titleOrder: [String: Int] = [
            (mapping.titleColumn ?? ""): 1,
            (mapping.amountColumn ?? ""): 2,
            (mapping.categoryColumn ?? ""): 3,
            (mapping.dateColumn ?? ""): 4,
            "Notes": 5,
            "Description": 5,
            "Memo": 5
        ]

        return fields.sorted { f1, f2 in
            let order1 = titleOrder[f1.propertyName] ?? 100
            let order2 = titleOrder[f2.propertyName] ?? 100
            if order1 != order2 {
                return order1 < order2
            }
            return f1.propertyName < f2.propertyName
        }
    }

    func updateFieldValue(_ value: DynamicFormValue) {
        fieldValues[value.propertyName] = value
        let display = value.stringValue ?? value.selectValue ?? (value.multiSelectValues?.joined(separator: ",")) ?? String(value.numberValue ?? 0)
        print("[AddTransactionVM] Updated field: \(value.propertyName) = \(display)")
    }

    func updateStringValue(propertyName: String, value: String) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.stringValue = value
        updateFieldValue(formValue)
    }

    func updateNumberValue(propertyName: String, value: Double?) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.numberValue = value
        updateFieldValue(formValue)
    }

    func updateBoolValue(propertyName: String, value: Bool) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.boolValue = value
        updateFieldValue(formValue)
    }

    func updateDateValue(propertyName: String, value: Date?) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.dateValue = value
        updateFieldValue(formValue)
    }

    func updateSelectValue(propertyName: String, value: String?) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.selectValue = value
        updateFieldValue(formValue)
    }

    func updateMultiSelectValue(propertyName: String, values: [String]) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.multiSelectValues = values
        updateFieldValue(formValue)
    }

    func updateRelationValue(propertyName: String, ids: [String]) {
        guard let field = fields.first(where: { $0.propertyName == propertyName }) else { return }
        var formValue = DynamicFormValue(propertyName: propertyName, propertyType: field.propertyType)
        formValue.relationIds = ids
        updateFieldValue(formValue)
    }

    func loadRelationOptions(for field: DynamicFormField) {
        guard let databaseId = field.relationDataSourceId else {
            print("[AddTransactionVM] No relation database ID for '\(field.propertyName)'")
            delegate?.didFailToLoadRelationOptions(for: field.propertyName, error: "No relation data source ID")
            return
        }

        print("[AddTransactionVM] Loading relation options for '\(field.propertyName)' from database: \(databaseId)")

        TransactionInsertService.shared.loadRelationOptions(databaseId: databaseId, token: token) { [weak self] result in
            switch result {
            case .success(let options):
                print("[AddTransactionVM] Loaded \(options.count) relation options for '\(field.propertyName)': \(options.map { $0.title }.joined(separator: ", "))")
                self?.relationOptions[field.propertyName] = options
                self?.delegate?.didLoadRelationOptions(for: field.propertyName, options: options)

            case .failure(let error):
                print("[AddTransactionVM] Failed to load relation options for '\(field.propertyName)': \(error)")
                self?.delegate?.didFailToLoadRelationOptions(for: field.propertyName, error: error.localizedDescription)
            }
        }
    }

    func validateForm() -> (isValid: Bool, missingFields: [String]) {
        var missingFields: [String] = []

        for field in fields {
            guard field.isRequired else { continue }

            if let value = fieldValues[field.propertyName] {
                if value.isEmpty {
                    missingFields.append(field.propertyName)
                }
            } else {
                missingFields.append(field.propertyName)
            }
        }

        let isValid = missingFields.isEmpty

        if !isValid {
            print("[AddTransactionVM] Validation failed. Missing fields: \(missingFields.joined(separator: ", "))")
        } else {
            print("[AddTransactionVM] Validation passed")
        }

        delegate?.didValidateForm(isValid: isValid, missingFields: missingFields)
        return (isValid, missingFields)
    }

    func saveTransaction() {
        print("[AddTransactionVM] Save button tapped")
        print("[AddTransactionVM] Transaction type: \(selectedRole.displayName)")
        print("[AddTransactionVM] Target database ID: \(targetDatabaseId ?? "nil")")

        let validation = validateForm()

        guard validation.isValid else {
            delegate?.didFailToSave(error: "Please fill in all required fields: \(validation.missingFields.joined(separator: ", "))")
            return
        }

        guard let databaseId = targetDatabaseId else {
            delegate?.didFailToSave(error: "No database configured")
            return
        }

        print("[AddTransactionVM] Form validation passed")

        var valuesToSave = Array(fieldValues.values)

        for i in valuesToSave.indices {
            if valuesToSave[i].propertyType == .title,
               let existing = valuesToSave[i].stringValue,
               existing.trimmingCharacters(in: .whitespaces).isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: Date())
                let fallbackTitle = "\(selectedRole.displayName) - \(dateStr)"
                print("[AddTransactionVM] Title empty, using fallback: \(fallbackTitle)")
                valuesToSave[i].stringValue = fallbackTitle
            }
        }

        print("[AddTransactionVM] Saving transaction with \(valuesToSave.count) field values")
        for val in valuesToSave {
            if val.propertyType == .relation {
                print("[AddTransactionVM] Relation field '\(val.propertyName)' -> IDs: \(val.relationIds ?? [])")
            } else {
                let display = val.stringValue ?? String(val.numberValue ?? 0)
                print("[AddTransactionVM] Field '\(val.propertyName)' (\(val.propertyType.rawValue)) = \(display)")
            }
        }

        delegate?.didStartSaving()

        TransactionInsertService.shared.insertTransaction(
            databaseId: databaseId,
            values: valuesToSave,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let page):
                print("[AddTransactionVM] Transaction saved successfully: \(page.id)")
                self?.delegate?.didSaveSuccessfully()

            case .failure(let error):
                print("[AddTransactionVM] Save failed: \(error.localizedDescription)")
                self?.delegate?.didFailToSave(error: error.localizedDescription)
            }
        }
    }
}