//
//  AddTransactionViewModel.swift
//  Notra
//

import Foundation

// MARK: - Manual Split Calculator

enum ManualSplitMethod: String {
    case equal = "manualEqual"
    case percent = "manualPercent"
    case customAmount = "manualCustom"
    case hhs = "manualHHS"
}

struct ManualSplitInputs {
    var entryMode: String?
    var myPercent: Double?
    var theirPercent: Double?
    var customAmount: Double?
    var extraAmount: Double?
}

struct ManualSplitResult {
    let paidAmount: Double
    let method: ManualSplitMethod
    let myShare: Double
    let theyOwe: Double
    let participantOwes: [String: Double]
    let validationError: String?
    let typeString: String
    let inputsDict: [String: Any]
    let participantsList: [[String: Any]]
    let splitDetailsJSON: String
}

func calculateManualSplit(
    paidAmount: Double,
    method: ManualSplitMethod,
    selectedPersonIds: Set<String>,
    inputs: ManualSplitInputs
) -> ManualSplitResult {
    let allPeople = SplitPeopleStore.shared.getPeople()
    let selectedCount = selectedPersonIds.count

    let myShare: Double
    let theyOwe: Double
    let participantOwes: [String: Double]
    let typeString: String
    let inputsDict: [String: Any]
    var validationError: String?

    switch method {
    case .equal:
        let totalParticipants = 1 + selectedCount
        let eachShare = paidAmount / Double(totalParticipants)
        myShare = eachShare
        theyOwe = paidAmount - myShare
        var owes: [String: Double] = [:]
        for pid in selectedPersonIds {
            owes[pid] = eachShare
        }
        participantOwes = owes
        typeString = "manualEqual"
        inputsDict = [:]

    case .percent:
        let entryMode = inputs.entryMode ?? "myPercent"
        let myPct = inputs.myPercent ?? 50
        let theirPct = inputs.theirPercent ?? 50

        if entryMode == "myPercent" {
            myShare = paidAmount * myPct / 100.0
            theyOwe = paidAmount - myShare
        } else {
            theyOwe = paidAmount * theirPct / 100.0
            myShare = paidAmount - theyOwe
        }

        if selectedCount > 0 {
            var owes: [String: Double] = [:]
            let eachOwe = theyOwe / Double(selectedCount)
            for pid in selectedPersonIds {
                owes[pid] = eachOwe
            }
            participantOwes = owes
        } else {
            participantOwes = [:]
        }

        typeString = "manualPercent"
        inputsDict = [
            "entryMode": entryMode,
            "myPercent": myPct,
            "theirPercent": theirPct
        ]

    case .customAmount:
        let entryMode = inputs.entryMode ?? "theyOwe"
        let amount = inputs.customAmount ?? 0

        if entryMode == "theyOwe" {
            theyOwe = amount
            myShare = paidAmount - theyOwe
        } else {
            myShare = amount
            theyOwe = paidAmount - myShare
        }

        if myShare < 0 || theyOwe < 0 {
            validationError = "Custom amount exceeds paid amount."
        }

        if selectedCount > 0 {
            var owes: [String: Double] = [:]
            let eachOwe = theyOwe / Double(selectedCount)
            for pid in selectedPersonIds {
                owes[pid] = eachOwe
            }
            participantOwes = owes
        } else {
            participantOwes = [:]
        }

        typeString = "manualCustom"
        inputsDict = [
            "entryMode": entryMode,
            "customAmount": amount
        ]

    case .hhs:
        let entryMode = inputs.entryMode ?? "iPayExtra"
        let extraAmount = inputs.extraAmount ?? 0
        let totalParticipants = 1 + selectedCount
        let baseShare = paidAmount / Double(totalParticipants)

        if entryMode == "extraTheyPay" {
            theyOwe = baseShare + extraAmount
            myShare = paidAmount - theyOwe
        } else {
            myShare = baseShare + extraAmount
            theyOwe = paidAmount - myShare
        }

        if myShare < 0 || theyOwe < 0 {
            validationError = "Extra amount exceeds paid amount."
        }

        if selectedCount > 0 {
            var owes: [String: Double] = [:]
            let eachOwe = theyOwe / Double(selectedCount)
            for pid in selectedPersonIds {
                owes[pid] = eachOwe
            }
            participantOwes = owes
        } else {
            participantOwes = [:]
        }

        typeString = "manualHHS"
        inputsDict = [
            "entryMode": entryMode,
            "extraAmount": extraAmount,
            "baseShare": baseShare
        ]
    }

    var participantsList: [[String: Any]] = []
    for pid in selectedPersonIds {
        guard let person = allPeople.first(where: { $0.id == pid }) else { continue }
        let owes = participantOwes[pid] ?? 0
        let entry: [String: Any] = [
            "id": person.id,
            "name": person.name,
            "owes": owes,
            "status": "pending",
            "settledAt": NSNull()
        ]
        participantsList.append(entry)
    }

    let splitData: [String: Any] = [
        "enabled": true,
        "paidAmount": paidAmount,
        "myShare": myShare,
        "theyOwe": theyOwe,
        "type": typeString,
        "status": "pending",
        "participants": participantsList,
        "inputs": inputsDict
    ]

    let data: [String: Any] = [
        "version": 2,
        "split": splitData
    ]

    var jsonString = ""
    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
       let str = String(data: jsonData, encoding: .utf8) {
        jsonString = str
    }

    print("[ManualSplitCalc] method=\(method.rawValue)")
    print("[ManualSplitCalc] paidAmount=\(paidAmount)")
    print("[ManualSplitCalc] selectedCount=\(selectedCount)")
    print("[ManualSplitCalc] selectedPeople=\(selectedPersonIds.sorted())")
    print("[ManualSplitCalc] inputs=\(inputsDict)")
    print("[ManualSplitCalc] myShare=\(myShare)")
    print("[ManualSplitCalc] theyOwe=\(theyOwe)")
    print("[ManualSplitCalc] participantOwes=\(participantOwes)")
    if case .hhs = method {
        let extra = inputs.extraAmount ?? 0
        let totalParticipants = 1 + selectedCount
        let baseShare = paidAmount / Double(totalParticipants)
        print("[ManualSplitCalc] method=HHS")
        print("[ManualSplitCalc] extraAmount=\(extra)")
        print("[ManualSplitCalc] baseShare=\(baseShare)")
    }

    return ManualSplitResult(
        paidAmount: paidAmount,
        method: method,
        myShare: myShare,
        theyOwe: theyOwe,
        participantOwes: participantOwes,
        validationError: validationError,
        typeString: typeString,
        inputsDict: inputsDict,
        participantsList: participantsList,
        splitDetailsJSON: jsonString
    )
}

enum SplitMethod: String, CaseIterable {
    case half = "50/50"
    case customAmount = "Custom Amount"
}

extension SplitMethod {
    var modernType: SplitMethodType {
        switch self {
        case .half: return .splitEqually
        case .customAmount: return .exactAmounts
        }
    }

    init(from type: SplitMethodType) {
        switch type {
        case .splitEqually: self = .half
        case .exactAmounts: self = .customAmount
        case .percent: self = .customAmount
        case .shares: self = .customAmount
        case .adjustment: self = .customAmount
        }
    }
}

protocol AddTransactionViewModelDelegate: AnyObject {
    func didLoadFields(_ fields: [DynamicFormField])
    func didFailToLoadFields(error: String)
    func didLoadRelationOptions(for propertyName: String, options: [(id: String, title: String)])
    func didFailToLoadRelationOptions(for propertyName: String, error: String)
    func didStartSaving()
    func didSaveSuccessfully()
    func didFailToSave(error: String)
    func didValidateForm(isValid: Bool, missingFields: [String])
    func didResetForm()
    func didAutoSelectMonthClassification(propertyName: String, title: String)
}

final class AddTransactionViewModel {
    weak var delegate: AddTransactionViewModelDelegate?

    private(set) var selectedRole: DatabaseRole = .expense
    private(set) var fields: [DynamicFormField] = []
    private(set) var fieldValues: [String: DynamicFormValue] = [:]
    private(set) var relationOptions: [String: [(id: String, title: String)]] = [:]
    private(set) var isFetchingFields = false
    private(set) var isSplitExpense = false
    private(set) var splitMethod: SplitMethod = .half
    private(set) var splitMethodType: SplitMethodType = .splitEqually
    private(set) var paidAmountForSplit: Double = 0
    private(set) var myShareAmountForSplit: Double = 0
    private(set) var reimbursementAmountForSplit: Double = 0
    private(set) var splitStatus: String = "pending"
    private(set) var selectedSplitPersonIds: Set<String> = []

    private(set) var lastManualSplitResult: ManualSplitResult?

    var hasSelectedSplitPeople: Bool { !selectedSplitPersonIds.isEmpty }

    var isLegacySplitWithoutParticipants: Bool {
        guard isEditMode, isSplitExpense, let tx = editingTransaction,
              let meta = tx.splitMetadata else { return false }
        let participants = meta.participants ?? []
        return participants.isEmpty
    }

    var totalSplitParticipants: Int {
        1 + selectedSplitPersonIds.count
    }

    // Method-specific inputs
    private(set) var splitMyShareExact: Double = 0
    private(set) var splitTheyOweExact: Double = 0
    private(set) var splitMyPercent: Double = 50
    private(set) var splitTheirPercent: Double = 50
    private(set) var splitAdjustmentAmount: Double = 0
    private(set) var splitAdjustmentMode: String = "extraIPay"
    private(set) var splitEntryMode: String = "myShare"

    private var mappings: [String: DatabaseMappingData] = [:]
    private var prefillData: [String: String]
    private var prefillApplied = false
    private(set) var editingTransaction: NormalizedTransaction?
    private(set) var lastCreatedPage: NotionPage?
    var isEditMode: Bool { editingTransaction != nil }

    private var token: String {
        return UserDefaultsManager.shared.notionToken ?? ""
    }

    var targetDatabaseId: String? {
        return mappings.values.first { $0.role == selectedRole }?.databaseId
    }

    var targetDatabaseMapping: DatabaseMappingData? {
        return mappings.values.first { $0.role == selectedRole }
    }

    init(prefillData: [String: String] = [:], initialRole: DatabaseRole = .expense, editingTransaction: NormalizedTransaction? = nil) {
        self.prefillData = prefillData
        self.editingTransaction = editingTransaction
        self.selectedRole = initialRole
        loadMappings()
        applyPrefillIfNeeded()
    }

    private func loadMappings() {
        mappings = ColumnMappingService.shared.loadDatabaseMappings()
        print("[AddTransactionVM] Loaded \(mappings.count) database mappings")
    }

    private func applyPrefillIfNeeded() {
        guard !prefillData.isEmpty else {
            print("[AddTransactionVM] No prefill data")
            return
        }
        print("[AddTransactionVM] Has prefill data: \(prefillData)")
    }

    private func applyPrefillToFields(columnMapping: ColumnMapping?) {
        guard !prefillData.isEmpty, !prefillApplied else { return }

        prefillApplied = true
        print("[AddTransactionVM] Applying prefill data...")

        guard let mapping = columnMapping else {
            print("[AddTransactionVM] No column mapping, cannot apply prefill")
            return
        }

        if let title = prefillData["title"], !title.isEmpty, let titleColumn = mapping.titleColumn {
            updateStringValue(propertyName: titleColumn, value: title)
            print("[AddTransactionVM] Prefilled title: \(title)")
        }

        if let amount = prefillData["amount"], !amount.isEmpty {
            let cleanAmount = amount.replacingOccurrences(of: ",", with: ".")
            if let amountValue = Double(cleanAmount), let amountColumn = mapping.amountColumn {
                updateNumberValue(propertyName: amountColumn, value: amountValue)
                print("[AddTransactionVM] Prefilled amount: \(amountValue)")
            } else {
                print("[AddTransactionVM] Invalid amount: \(amount)")
            }
        }

        if let dateString = prefillData["date"], !dateString.isEmpty, let dateColumn = mapping.dateColumn {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                updateDateValue(propertyName: dateColumn, value: date)
                print("[AddTransactionVM] Prefilled date: \(dateString)")
            } else {
                print("[AddTransactionVM] Invalid date format: \(dateString)")
            }
        }

        if let notes = prefillData["notes"], !notes.isEmpty {
            let notesColumn = findNotesColumn()
            if let column = notesColumn {
                updateStringValue(propertyName: column, value: notes)
                print("[AddTransactionVM] Prefilled notes: \(notes)")
            }
        }

        print("[AddTransactionVM] Prefill applied successfully")
    }

    private func applyEditPrefill(columnMapping: ColumnMapping?) {
        guard let editingTx = editingTransaction, let rawProps = editingTx.rawProperties else { return }
        print("[AddTransactionVM] Applying edit prefill for transaction: \(editingTx.id)")

        for field in fields {
            guard let propValue = rawProps[field.propertyName] else { continue }

            switch field.propertyType {
            case .title:
                if let text = extractText(from: propValue.title) {
                    updateStringValue(propertyName: field.propertyName, value: text)
                    print("[AddTransactionVM] Prefilled title: \(text)")
                }
            case .richText:
                if let text = extractText(from: propValue.richText) {
                    updateStringValue(propertyName: field.propertyName, value: text)
                    print("[AddTransactionVM] Prefilled richText: \(text)")
                }
            case .number:
                if let number = propValue.number {
                    updateNumberValue(propertyName: field.propertyName, value: number)
                    print("[AddTransactionVM] Prefilled number: \(number)")
                }
            case .date:
                if let start = propValue.date?.start {
                    let parts = start.prefix(10).components(separatedBy: "-")
                    if parts.count == 3,
                       let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) {
                        var components = DateComponents()
                        components.year = year
                        components.month = month
                        components.day = day
                        components.hour = 12
                        if let date = Calendar.current.date(from: components) {
                            updateDateValue(propertyName: field.propertyName, value: date)
                            print("[AddTransactionVM] Prefilled date: \(start)")
                        }
                    }
                }
            case .select, .status:
                if let name = propValue.select?.name {
                    updateSelectValue(propertyName: field.propertyName, value: name)
                    print("[AddTransactionVM] Prefilled select: \(name)")
                }
            case .multiSelect:
                let names = propValue.multiSelect?.compactMap { $0.name } ?? []
                if !names.isEmpty {
                    updateMultiSelectValue(propertyName: field.propertyName, values: names)
                    print("[AddTransactionVM] Prefilled multiSelect: \(names)")
                }
            case .relation:
                let ids = propValue.relation?.compactMap { $0.id } ?? []
                if !ids.isEmpty {
                    updateRelationValue(propertyName: field.propertyName, ids: ids)
                    print("[AddTransactionVM] Prefilled relation: \(ids)")
                }
            case .checkbox:
                if let value = propValue.checkbox {
                    updateBoolValue(propertyName: field.propertyName, value: value)
                    print("[AddTransactionVM] Prefilled checkbox: \(value)")
                }
            default:
                break
            }
        }

        if selectedRole == .expense, let rawProps = editingTx.rawProperties {
            var parsedFromMetadata = false
            let metadataCol = columnMapping?.expenseAppMetadataProperty
                if let col = metadataCol, let prop = rawProps[col], let richText = prop.richText {
                    for item in richText {
                        guard let text = item.plainText ?? item.text?.content,
                              let data = text.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let split = json["split"] as? [String: Any],
                              let enabled = split["enabled"] as? Bool, enabled else { continue }
                        let paid = split["paidAmount"] as? Double ?? 0
                        let myShare = split["myShare"] as? Double ?? 0
                        let theyOwe = split["theyOwe"] as? Double ?? 0
                        let typeStr = split["type"] as? String ?? "50/50"
                        let statusStr = split["status"] as? String ?? "pending"
                        let rawInputs = split["inputs"] as? [String: Any]
                        if paid > 0 {
                            isSplitExpense = true
                            paidAmountForSplit = paid
                            myShareAmountForSplit = myShare > 0 ? myShare : (editingTx.amount)
                            let resolvedType = SplitMethodType.fromLegacy(typeStr)
                            splitMethodType = resolvedType
                            splitMethod = SplitMethod(from: resolvedType)
                            reimbursementAmountForSplit = theyOwe
                            splitStatus = statusStr
                            let hasV2Participants = split["participants"] is [[String: Any]]
                            print("[EditSplit] loaded existing split version=\(json["version"] as? Int ?? 1)")
                            print("[EditSplit] legacySplitWithoutParticipants=\(!hasV2Participants)")
                            if typeStr == "manualEqual", let participants = split["participants"] as? [[String: Any]] {
                                for pData in participants {
                                    guard let pid = pData["id"] as? String else { continue }
                                    selectedSplitPersonIds.insert(pid)
                                }
                            }
                            if let inputs = rawInputs {
                                splitMyPercent = inputs["myPercent"] as? Double ?? 50
                                splitTheirPercent = inputs["theirPercent"] as? Double ?? 50
                                splitAdjustmentAmount = inputs["adjustmentAmount"] as? Double ?? 0
                                splitAdjustmentMode = inputs["adjustmentMode"] as? String ?? "extraIPay"
                                splitEntryMode = inputs["entryMode"] as? String ?? "myShare"
                                if let exact = inputs["myShare"] as? Double {
                                    myShareAmountForSplit = exact
                                    splitMyShareExact = exact
                                }
                                if let owe = inputs["theyOwe"] as? Double {
                                    splitTheyOweExact = owe
                                }
                                // Map old shares to exact for editing
                                if resolvedType == .shares {
                                    if let myS = inputs["myShares"] as? Double, let theirS = inputs["theirShares"] as? Double, (myS + theirS) > 0 {
                                        let ratio = myS / (myS + theirS)
                                        let shareEstimate = paid * ratio
                                        myShareAmountForSplit = shareEstimate
                                        splitMyShareExact = shareEstimate
                                        splitTheyOweExact = max(paid - shareEstimate, 0)
                                    }
                                    splitMethodType = .exactAmounts
                                }
                            }
                            recalculateSplit()
                            parsedFromMetadata = true
                        }
                        break
                    }
                }
            if !parsedFromMetadata {
                let paidField = rawProps.first { key, value in
                    let lower = key.lowercased()
                    return (lower.contains("paid amount") || lower.contains("original amount") || lower.contains("total paid") || lower.contains("actual paid")) && value.number != nil
                }
                if let (_, paidValue) = paidField, let paidAmount = paidValue.number {
                    isSplitExpense = true
                    paidAmountForSplit = paidAmount
                    let amountColumn = mappings.values.first { $0.role == .expense }?.columnMapping?.amountColumn
                    if let amountCol = amountColumn, let amountVal = rawProps[amountCol]?.number {
                        myShareAmountForSplit = amountVal
                    }
                    splitMethodType = myShareAmountForSplit == paidAmount / 2 ? .splitEqually : .exactAmounts
                    splitMethod = SplitMethod(from: splitMethodType)
                    recalculateSplit()
                }
            }
        }

        print("[AddTransactionVM] Edit prefill applied successfully")
    }

    private func extractText(from richText: [NotionRichText]?) -> String? {
        guard let items = richText else { return nil }
        for item in items {
            if let text = item.plainText, !text.isEmpty { return text }
            if let text = item.text?.content, !text.isEmpty { return text }
        }
        return nil
    }

    private func findNotesColumn() -> String? {
        let notesVariants = ["Notes", "notes", "Description", "description", "Memo", "memo"]
        for variant in notesVariants {
            if fields.contains(where: { $0.propertyName.lowercased() == variant.lowercased() }) {
                return fields.first { $0.propertyName.lowercased() == variant.lowercased() }?.propertyName
            }
        }
        return nil
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

            if propName == columnMapping?.expenseAppMetadataProperty {
                var formValue = DynamicFormValue(propertyName: propName, propertyType: notionType)
                fieldValues[propName] = formValue
                print("[AddTransactionVM] Skipping Split Details column from form: \(propName)")
                continue
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

        applyPrefillToFields(columnMapping: columnMapping)
        if editingTransaction != nil {
            applyEditPrefill(columnMapping: columnMapping)
        }
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

    func resetForm() {
        print("[AddTransactionVM] Resetting form after successful save")
        for field in fields {
            var formValue = DynamicFormValue(propertyName: field.propertyName, propertyType: field.propertyType)
            if field.propertyType == .date {
                formValue.dateValue = Date()
            }
            fieldValues[field.propertyName] = formValue
        }
        resetSplitState()
        print("[AddTransactionVM] Form reset complete. Date set to today.")
        autoSelectMonthClassification(for: Date())
        delegate?.didResetForm()
    }

    var hasPaidAmountField: Bool {
        fields.contains { field in
            field.propertyType == .number && (
                field.propertyName.lowercased().contains("paid amount") ||
                field.propertyName.lowercased().contains("original amount") ||
                field.propertyName.lowercased().contains("total paid") ||
                field.propertyName.lowercased().contains("actual paid")
            )
        }
    }

    var monthClassificationFieldName: String? {
        return fields.first(where: {
            $0.propertyType == .relation && $0.propertyName.lowercased().contains("month classification")
        })?.propertyName
    }

    func autoSelectMonthClassification(for date: Date) {
        guard let fieldName = monthClassificationFieldName else {
            print("[AddTransactionVM] No Month Classification field found in schema")
            return
        }

        guard let options = relationOptions[fieldName], !options.isEmpty else {
            print("[AddTransactionVM] Month Classification options not yet loaded, will auto-select when available")
            return
        }

        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        guard let monthNames = dateFormatter.monthSymbols, let shortMonthNames = dateFormatter.shortMonthSymbols else {
            print("[AddTransactionVM] Could not get month symbols")
            return
        }
        let monthName = monthNames[month - 1]
        let shortName = shortMonthNames[month - 1]

        let candidates: [String] = [
            "\(monthName) \(year)",
            "\(shortName) \(year)",
            "\(monthName), \(year)",
            "\(shortName), \(year)",
            String(format: "%04d-%02d", year, month),
            String(format: "%02d-%04d", month, year),
            "\(monthName) \(String(year))",
            "\(shortName) \(String(year))",
            monthName.uppercased() + " \(year)",
            monthName,
            shortName,
            monthName.uppercased()
        ]

        for candidate in candidates {
            if let match = options.first(where: {
                $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(candidate) == .orderedSame
            }) {
                updateRelationValue(propertyName: fieldName, ids: [match.id])
                delegate?.didAutoSelectMonthClassification(propertyName: fieldName, title: match.title)
                print("[AddTransactionVM] Auto-selected Month Classification: \(match.title) for \(monthName) \(year)")
                return
            }
        }

        for option in options {
            let title = option.title.trimmingCharacters(in: .whitespaces)
            if title.localizedCaseInsensitiveContains(monthName) && title.contains(String(year)) {
                updateRelationValue(propertyName: fieldName, ids: [option.id])
                delegate?.didAutoSelectMonthClassification(propertyName: fieldName, title: option.title)
                print("[AddTransactionVM] Auto-selected Month Classification (contains match): \(option.title)")
                return
            }
            if title.localizedCaseInsensitiveContains(shortName) && title.contains(String(year)) {
                updateRelationValue(propertyName: fieldName, ids: [option.id])
                delegate?.didAutoSelectMonthClassification(propertyName: fieldName, title: option.title)
                print("[AddTransactionVM] Auto-selected Month Classification (short contains match): \(option.title)")
                return
            }
        }

        print("[AddTransactionVM] No matching Month Classification option found for \(monthName) \(year)")
    }

    func setSplitEnabled(_ enabled: Bool) {
        isSplitExpense = enabled
        if !enabled {
            selectedSplitPersonIds = []
        }
        recalculateSplit()
    }

    func toggleSplitPerson(_ person: SplitPerson) {
        print("[ManualSplit] toggleSplitPerson \(person.name) id=\(person.id)")
        if selectedSplitPersonIds.contains(person.id) {
            selectedSplitPersonIds.remove(person.id)
            print("[ManualSplit] removed \(person.name)")
        } else {
            selectedSplitPersonIds.insert(person.id)
            print("[ManualSplit] added \(person.name)")
        }
        recalculateSplit()
    }

    func addSplitPerson(name: String) {
        let person = SplitPeopleStore.shared.addPerson(name: name)
        selectedSplitPersonIds.insert(person.id)
        recalculateSplit()
    }

    func setSplitMethod(_ method: SplitMethod) {
        splitMethod = method
        splitMethodType = method.modernType
        recalculateSplit()
    }

    func setSplitMethodType(_ type: SplitMethodType) {
        splitMethodType = type
        splitMethod = SplitMethod(from: type)
        recalculateSplit()
    }

    func setMyShareForSplit(_ share: Double) {
        myShareAmountForSplit = share
        reimbursementAmountForSplit = max(paidAmountForSplit - myShareAmountForSplit, 0)
    }

    func setPaidAmountForSplit(_ amount: Double) {
        paidAmountForSplit = amount
        recalculateSplit()
    }

    func setSplitMyPercent(_ pct: Double) {
        splitMyPercent = pct
        splitTheirPercent = max(100 - pct, 0)
        splitEntryMode = "myPercent"
        recalculateSplit()
    }

    func setSplitTheirPercent(_ pct: Double) {
        splitTheirPercent = pct
        splitMyPercent = max(100 - pct, 0)
        splitEntryMode = "theirPercent"
        recalculateSplit()
    }

    func setSplitMyShareExact(_ amount: Double) {
        splitMyShareExact = amount
        splitTheyOweExact = max(paidAmountForSplit - amount, 0)
        splitEntryMode = "myShare"
        recalculateSplit()
    }

    func setSplitTheyOweExact(_ amount: Double) {
        splitTheyOweExact = amount
        splitMyShareExact = max(paidAmountForSplit - amount, 0)
        splitEntryMode = "theyOwe"
        recalculateSplit()
    }

    func setSplitAdjustmentAmount(_ amount: Double) {
        splitAdjustmentAmount = amount
        recalculateSplit()
    }

    func setSplitAdjustmentMode(_ mode: String) {
        splitAdjustmentMode = mode
        recalculateSplit()
    }

    private func recalculateSplit() {
        guard isSplitExpense, paidAmountForSplit > 0 else {
            myShareAmountForSplit = paidAmountForSplit
            reimbursementAmountForSplit = 0
            lastManualSplitResult = nil
            return
        }
        print("[ManualSplit] selectedPersonIds=\(selectedSplitPersonIds.sorted())")
        print("[ManualSplit] paidAmount=\(paidAmountForSplit)")
        print("[ManualSplit] splitMethodType=\(splitMethodType.rawValue)")
        if hasSelectedSplitPeople {
            let method: ManualSplitMethod
            switch splitMethodType {
            case .percent: method = .percent
            case .exactAmounts: method = .customAmount
            case .adjustment: method = .hhs
            default: method = .equal
            }
            let inputs = ManualSplitInputs(
                entryMode: splitMethodType == .adjustment ? splitAdjustmentMode : splitEntryMode,
                myPercent: splitMyPercent,
                theirPercent: splitTheirPercent,
                customAmount: splitMethodType == .exactAmounts
                    ? (splitEntryMode == "theyOwe" ? splitTheyOweExact : splitMyShareExact) : nil,
                extraAmount: splitMethodType == .adjustment ? splitAdjustmentAmount : nil
            )
            let result = calculateManualSplit(
                paidAmount: paidAmountForSplit,
                method: method,
                selectedPersonIds: selectedSplitPersonIds,
                inputs: inputs
            )
            myShareAmountForSplit = result.myShare
            reimbursementAmountForSplit = result.theyOwe
            lastManualSplitResult = result
        } else {
            lastManualSplitResult = nil
            let result = SplitCalculator.calculate(
                paidAmount: paidAmountForSplit,
                method: splitMethodType,
                myShareExact: (splitMethodType == .exactAmounts && splitEntryMode != "theyOwe") ? splitMyShareExact : nil,
                theyOweExact: (splitMethodType == .exactAmounts && splitEntryMode == "theyOwe") ? splitTheyOweExact : nil,
                myPercent: (splitMethodType == .percent) ? splitMyPercent : nil,
                adjustmentAmount: splitAdjustmentAmount,
                adjustmentMode: splitAdjustmentMode
            )
            myShareAmountForSplit = result.myShare
            reimbursementAmountForSplit = result.theyOwe
        }
    }

    private func buildSplitMetadataJSON(existingJSON: String? = nil) -> String {
        if let result = lastManualSplitResult {
            print("[ManualSplitSave] using result method=\(result.method.rawValue)")
            print("[ManualSplitSave] Split Details JSON=\(result.splitDetailsJSON)")
            return result.splitDetailsJSON
        }

        var data: [String: Any] = [:]

        if let existing = existingJSON,
           let existingData = existing.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            data = parsed
        }

        var inputs: [String: Any] = [:]
        switch splitMethodType {
        case .exactAmounts:
            inputs["myShare"] = splitMyShareExact
            inputs["theyOwe"] = splitTheyOweExact
            inputs["entryMode"] = splitEntryMode
        case .percent:
            inputs["myPercent"] = splitMyPercent
            inputs["theirPercent"] = splitTheirPercent
            inputs["entryMode"] = splitEntryMode
        case .shares:
            break
        case .adjustment:
            inputs["adjustmentAmount"] = splitAdjustmentAmount
            inputs["adjustmentMode"] = splitAdjustmentMode
        case .splitEqually:
            break
        }

        data["version"] = 1
        data["split"] = [
            "enabled": true,
            "paidAmount": paidAmountForSplit,
            "myShare": myShareAmountForSplit,
            "theyOwe": reimbursementAmountForSplit,
            "type": splitMethodType.rawValue,
            "status": splitStatus,
            "splitWith": NSNull(),
            "inputs": inputs
        ] as [String: Any]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }

    func resetSplitState() {
        isSplitExpense = false
        splitMethod = .half
        splitMethodType = .splitEqually
        paidAmountForSplit = 0
        myShareAmountForSplit = 0
        reimbursementAmountForSplit = 0
        splitStatus = "pending"
        splitMyShareExact = 0
        splitTheyOweExact = 0
        splitMyPercent = 50
        splitTheirPercent = 50
        splitAdjustmentAmount = 0
        splitAdjustmentMode = "extraIPay"
        splitEntryMode = "myShare"
        selectedSplitPersonIds = []
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

        if isSplitExpense && selectedRole == .expense && !hasSelectedSplitPeople {
            delegate?.didFailToSave(error: "Select at least one person to split with.")
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

        if isSplitExpense && selectedRole == .expense {
            if hasSelectedSplitPeople {
                recalculateSplit()
            }
            let amountFieldName = mappings.values.first { $0.role == .expense }?.columnMapping?.amountColumn
            if let splitResult = lastManualSplitResult {
                let splitDetailsJSON = splitResult.splitDetailsJSON
                print("[ManualSplitSave] selectedMethod=\(splitMethodType.rawValue)")
                print("[ManualSplitSave] savedSplitType=\(splitResult.typeString)")
                print("[ManualSplitSave] splitInputs=\(splitResult.inputsDict)")
                print("[ManualSplitSave] Amount field=\(splitResult.myShare)")
                print("[ManualSplitSave] Split Details JSON=\(splitDetailsJSON)")
                for i in valuesToSave.indices {
                    if valuesToSave[i].propertyType == .number {
                        if valuesToSave[i].propertyName == amountFieldName {
                            let oldVal = valuesToSave[i].numberValue ?? 0
                            valuesToSave[i].numberValue = splitResult.myShare
                            print("[EditSplit] updating Notion Amount=\(splitResult.myShare) (was \(oldVal))")
                        }
                    }
                    if valuesToSave[i].propertyType == .richText {
                        let metadataCol = targetDatabaseMapping?.columnMapping?.expenseAppMetadataProperty
                        if let col = metadataCol, valuesToSave[i].propertyName == col {
                            valuesToSave[i].stringValue = splitDetailsJSON
                            print("[EditSplit] updating Notion Split Details=\(splitDetailsJSON)")
                        }
                    }
                }
            } else {
                for i in valuesToSave.indices {
                    if valuesToSave[i].propertyType == .number {
                        if valuesToSave[i].propertyName == amountFieldName {
                            valuesToSave[i].numberValue = myShareAmountForSplit
                        }
                    }
                    if valuesToSave[i].propertyType == .richText {
                        let metadataCol = targetDatabaseMapping?.columnMapping?.expenseAppMetadataProperty
                        if let col = metadataCol, valuesToSave[i].propertyName == col {
                            valuesToSave[i].stringValue = buildSplitMetadataJSON()
                        }
                    }
                }
            }
        }

        delegate?.didStartSaving()

        if let editingTx = editingTransaction {
            TransactionInsertService.shared.updateTransaction(
                pageId: editingTx.id,
                values: valuesToSave,
                token: token
            ) { [weak self] result in
                switch result {
                case .success(let page):
                    print("[EditSplit] update success pageId=\(page.id)")
                    self?.lastCreatedPage = page
                    self?.delegate?.didSaveSuccessfully()

                case .failure(let error):
                    print("[AddTransactionVM] Update failed: \(error.localizedDescription)")
                    self?.delegate?.didFailToSave(error: error.localizedDescription)
                }
            }
        } else {
            TransactionInsertService.shared.insertTransaction(
                databaseId: databaseId,
                values: valuesToSave,
                token: token
            ) { [weak self] result in
                switch result {
                case .success(let page):
                    print("[AddTransactionVM] Transaction saved successfully: \(page.id)")
                    self?.lastCreatedPage = page
                    self?.delegate?.didSaveSuccessfully()

                case .failure(let error):
                    print("[AddTransactionVM] Save failed: \(error.localizedDescription)")
                    self?.delegate?.didFailToSave(error: error.localizedDescription)
                }
            }
        }
    }
}