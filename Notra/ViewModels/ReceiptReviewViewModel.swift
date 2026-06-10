import Foundation

enum ReceiptReviewError: LocalizedError {
    case noExpenseDatabase
    case noDatabaseId
    case noItemsToCreate
    case noCategorySelected
    case insertFailed(String)

    var errorDescription: String? {
        switch self {
        case .noExpenseDatabase: return "No expense database configured."
        case .noDatabaseId: return "No expense database ID found."
        case .noItemsToCreate: return "No items to create."
        case .noCategorySelected: return "Please select a category before creating expenses."
        case .insertFailed(let msg): return "Insert failed: \(msg)"
        }
    }
}

protocol ReceiptReviewViewModelDelegate: AnyObject {
    func didUpdateSummary()
    func didStartCreatingTransactions()
    func didCreateTransactions()
    func didFailWithError(_ error: String)
    func didLoadCategoryOptions()
}

final class ReceiptReviewViewModel {

    weak var delegate: ReceiptReviewViewModelDelegate?

    private(set) var receiptResult: GeminiReceiptResult

    var merchantName: String {
        get { receiptResult.merchant ?? "" }
        set { receiptResult.merchant = newValue }
    }

    var displayMerchant: String { receiptResult.displayMerchant }
    var platform: String? { receiptResult.platform }
    var receiptDate: Date? {
        get { receiptResult.date }
        set { receiptResult.date = newValue }
    }
    var orderNumber: String? { receiptResult.orderNumber }

    var items: [GeminiReceiptItem] { receiptResult.items }
    var summary: GeminiReceiptSummary { receiptResult.summary }
    var adjustments: [GeminiReceiptAdjustment] { receiptResult.adjustments }
    var warnings: [String] { receiptResult.warnings }
    var hasAdjustments: Bool { !receiptResult.adjustments.isEmpty }
    var hasWarnings: Bool { !receiptResult.warnings.isEmpty }
    var hasReceiptSummary: Bool { !receiptResult.summary.isEmpty }

    var receiptSubtotal: Double? { receiptResult.summary.itemsSubtotal }
    var receiptTax: Double? { receiptResult.summary.tax }
    var receiptDeliveryFee: Double? { receiptResult.summary.deliveryFee }
    var receiptDeliveryCharged: Double? { nil }
    var receiptTip: Double? { receiptResult.summary.tip }
    var receiptTotal: Double? { receiptResult.summary.totalCharged ?? receiptResult.summary.total }

    var hasReceiptSummaryData: Bool { !receiptResult.summary.isEmpty }

    var includeTaxProportionally: Bool = true
    var splitMethod: SplitMethodType = .splitEqually

    // MARK: - Category Support

    private(set) var categoryOptions: [(id: String, title: String)] = []
    private(set) var isLoadingCategories = false
    var hasCategoryOptions: Bool { !categoryOptions.isEmpty }
    private(set) var selectedCategoryId: String?
    private(set) var selectedCategoryName: String?
    private var suggestedCategoryName: String?
    private var categoryColumnType: String = "select"
    private var isRelationCategoryField: Bool = false

    private let token: String
    private let columnMappingService = ColumnMappingService.shared
    private let transactionInsertService = TransactionInsertService.shared

    init(receiptResult: GeminiReceiptResult, token: String) {
        self.receiptResult = receiptResult
        self.token = token
        loadCategoryOptions()
    }

    // MARK: - Category Options Loading

    private func loadCategoryOptions() {
        let mappings = columnMappingService.loadDatabaseMappings()
        guard let expenseMapping = mappings.values.first(where: { $0.role == .expense }),
              let columnMapping = expenseMapping.columnMapping,
              columnMapping.categoryColumn != nil else {
            return
        }

        categoryColumnType = expenseMapping.categoryType ?? "select"
        isRelationCategoryField = columnMapping.categoryRelationDataSourceId != nil

        if let merchant = receiptResult.merchant {
            let engine = ExpenseCategorySuggestionEngine()
            let suggestions = engine.suggestions(for: merchant)
            suggestedCategoryName = suggestions.first?.displayName
            if !isRelationCategoryField {
                selectCategory(id: suggestedCategoryName ?? "", name: suggestedCategoryName ?? "")
            }
        }

        if let dsId = columnMapping.categoryRelationDataSourceId {
            isLoadingCategories = true
            transactionInsertService.loadRelationOptions(databaseId: dsId, token: token) { [weak self] result in
                guard let self = self else { return }
                self.isLoadingCategories = false
                switch result {
                case .success(let options):
                    self.categoryOptions = options
                    if self.selectedCategoryId == nil {
                        self.preselectFromLoadedOptions()
                    }
                case .failure:
                    break
                }
                self.delegate?.didLoadCategoryOptions()
            }
        } else {
            delegate?.didLoadCategoryOptions()
        }
    }

    private func preselectFromLoadedOptions() {
        guard let suggested = suggestedCategoryName?.lowercased() else { return }
        for option in categoryOptions {
            let title = option.title.lowercased()
            if title == suggested || title.contains(suggested) || suggested.contains(title) {
                selectCategory(id: option.id, name: option.title)
                return
            }
        }
    }

    func selectCategory(id: String, name: String) {
        selectedCategoryId = id
        selectedCategoryName = name
    }

    // MARK: - Item Management

    func setClassification(for itemId: String, classification: ReceiptItemClassification) {
        if let idx = receiptResult.items.firstIndex(where: { $0.id == itemId }) {
            receiptResult.items[idx].classification = classification
            delegate?.didUpdateSummary()
        }
    }

    func updateItemName(itemId: String, name: String) {
        if let idx = receiptResult.items.firstIndex(where: { $0.id == itemId }) {
            receiptResult.items[idx].name = name
        }
    }

    func updateItemPrice(itemId: String, price: Double) {
        if let idx = receiptResult.items.firstIndex(where: { $0.id == itemId }) {
            receiptResult.items[idx].finalPrice = price
            delegate?.didUpdateSummary()
        }
    }

    func deleteItem(itemId: String) {
        receiptResult.items.removeAll { $0.id == itemId }
        delegate?.didUpdateSummary()
    }

    func addItem(name: String, price: Double) {
        let item = GeminiReceiptItem(
            id: UUID().uuidString,
            name: name,
            quantity: nil,
            unitPrice: nil,
            finalPrice: price,
            categoryHint: nil,
            rawText: nil,
            classification: .mine,
            isEditable: true
        )
        receiptResult.items.append(item)
        delegate?.didUpdateSummary()
    }

    // MARK: - Multi-Person Split

    var splitPeople: [SplitPerson] { SplitPeopleStore.shared.getPeople() }

    func addPerson(name: String) {
        SplitPeopleStore.shared.addPerson(name: name)
        delegate?.didUpdateSummary()
    }

    func deletePerson(id: String) {
        for i in receiptResult.items.indices {
            receiptResult.items[i].sharedWith.removeAll { $0 == id }
        }
        SplitPeopleStore.shared.deletePerson(id: id)
        delegate?.didUpdateSummary()
    }

    func setSharedWith(for itemId: String, personIds: [String]) {
        if let idx = receiptResult.items.firstIndex(where: { $0.id == itemId }) {
            receiptResult.items[idx].sharedWith = personIds
            delegate?.didUpdateSummary()
        }
    }

    func sharedWithPersonNames(for itemId: String) -> [String] {
        guard let item = receiptResult.items.first(where: { $0.id == itemId }) else { return [] }
        let people = SplitPeopleStore.shared.getPeople()
        return item.sharedWith.compactMap { pid in people.first(where: { $0.id == pid })?.name }
    }

    var hasSharedItemsWithoutPeople: Bool {
        receiptResult.items.contains { $0.classification == .shared && $0.sharedWith.isEmpty }
    }

    // MARK: - Split Calculations

    var hasTax: Bool { (receiptResult.summary.tax ?? 0) > 0 }
    var taxAmount: Double { receiptResult.summary.tax ?? 0 }

    var personalTotal: Double {
        let mineItems = receiptResult.items
            .filter { $0.classification == .mine }
            .reduce(0.0) { $0 + $1.finalPrice }
        if includeTaxProportionally, let tax = receiptResult.summary.tax, tax > 0 {
            let allTotal = receiptResult.items
                .filter { $0.classification != .ignore }
                .reduce(0.0) { $0 + $1.finalPrice }
            if allTotal > 0 {
                return mineItems + (mineItems / allTotal) * tax
            }
        }
        return mineItems
    }

    var sharedTotal: Double {
        let sharedItems = receiptResult.items
            .filter { $0.classification == .shared }
            .reduce(0.0) { $0 + $1.finalPrice }
        if includeTaxProportionally, let tax = receiptResult.summary.tax, tax > 0 {
            let allTotal = receiptResult.items
                .filter { $0.classification != .ignore }
                .reduce(0.0) { $0 + $1.finalPrice }
            if allTotal > 0 {
                return sharedItems + (sharedItems / allTotal) * tax
            }
        }
        return sharedItems
    }

    var myShare: Double {
        if hasSharedItems {
            return multiPersonSettlement.myShare
        }
        return personalTotal
    }

    var theyOwe: Double {
        if hasSharedItems {
            return multiPersonSettlement.theyOwe
        }
        return 0
    }

    var totalCounted: Double {
        myShare
    }

    var hasPersonalItems: Bool { receiptResult.items.contains { $0.classification == .mine } }
    var hasSharedItems: Bool { receiptResult.items.contains { $0.classification == .shared } }

    var mineCount: Int {
        receiptResult.items.filter { $0.classification == .mine }.count
    }

    var sharedCount: Int {
        receiptResult.items.filter { $0.classification == .shared }.count
    }

    var includedTotal: Double {
        let sub = receiptResult.items
            .filter { $0.classification != .ignore }
            .reduce(0.0) { $0 + $1.finalPrice }
        if includeTaxProportionally, let tax = receiptResult.summary.tax, tax > 0 {
            return sub + tax
        }
        return sub
    }

    var personOwes: [(name: String, amount: Double)] {
        guard hasSharedItems else { return [] }
        let settlement = multiPersonSettlement
        let people = SplitPeopleStore.shared.getPeople()
        return settlement.personOwes.compactMap { pid, amount in
            guard let person = people.first(where: { $0.id == pid }) else { return nil }
            return (person.name, amount)
        }
    }

    /// Multi-person settlement: compute myShare, theyOwe, and per-person owes.
    /// Each shared item is split equally among Me + selected people.
    /// Tax is allocated proportionally when includeTaxProportionally is ON.
    private var multiPersonSettlement: (myShare: Double, theyOwe: Double, personOwes: [String: Double]) {
        var myShare = 0.0
        var personOwes: [String: Double] = [:]
        var allPreTaxTotal = 0.0

        let includedItems = receiptResult.items.filter { $0.classification != .ignore }

        struct ItemAlloc {
            var myPreTax: Double
            var personPreTax: [String: Double]
        }
        var allocs: [ItemAlloc] = []

        for item in includedItems {
            if item.classification == .mine {
                allPreTaxTotal += item.finalPrice
                allocs.append(ItemAlloc(myPreTax: item.finalPrice, personPreTax: [:]))
            } else if item.classification == .shared {
                let sharedWith = item.sharedWith
                guard !sharedWith.isEmpty else { continue }
                let count = 1 + sharedWith.count
                let share = item.finalPrice / Double(count)
                allPreTaxTotal += item.finalPrice
                var pMap: [String: Double] = [:]
                for pid in sharedWith {
                    pMap[pid] = share
                }
                allocs.append(ItemAlloc(myPreTax: share, personPreTax: pMap))
            }
        }

        let tax = includeTaxProportionally ? (receiptResult.summary.tax ?? 0) : 0

        for alloc in allocs {
            let myTax = allPreTaxTotal > 0 ? (alloc.myPreTax / allPreTaxTotal) * tax : 0
            myShare += alloc.myPreTax + myTax
            for (pid, preTax) in alloc.personPreTax {
                let personTax = allPreTaxTotal > 0 ? (preTax / allPreTaxTotal) * tax : 0
                personOwes[pid, default: 0] += preTax + personTax
            }
        }

        let theyOwe = personOwes.values.reduce(0, +)
        return (myShare, theyOwe, personOwes)
    }

    var isRelationCategory: Bool { isRelationCategoryField }

    var isCategoryRequired: Bool {
        isRelationCategory
    }

    var isCategorySelected: Bool {
        if isRelationCategory {
            return selectedCategoryId != nil
        }
        return true
    }

    var canCreateExpenses: Bool {
        guard mineCount + sharedCount > 0 else { return false }
        guard !isCategoryRequired || selectedCategoryId != nil else { return false }
        guard !hasSharedItemsWithoutPeople else { return false }
        return true
    }

    var createButtonTitle: String {
        if mineCount + sharedCount == 0 { return "Create Expenses" }
        if hasSharedItems { return "Create Split Expense" }
        return "Create 1 Expense"
    }

    var helperText: String {
        if hasSharedItemsWithoutPeople {
            return "Select at least one person for each shared item"
        }
        if isCategoryRequired && selectedCategoryId == nil {
            return "Select a category to continue"
        }
        if mineCount + sharedCount == 0 {
            return "Mark items as Mine or Shared to create expenses"
        }
        return ""
    }

    var isCategoryRequiredAndMissing: Bool {
        isRelationCategory && selectedCategoryId == nil
    }

    // MARK: - Transaction Creation

    func createTransactions(completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        if isRelationCategory {
            if isLoadingCategories {
                completion(.failure(.insertFailed("Categories are still loading. Please wait.")))
                return
            }
            guard selectedCategoryId != nil else {
                completion(.failure(.noCategorySelected))
                return
            }
        }

        guard mineCount + sharedCount > 0 else {
            completion(.failure(.noItemsToCreate))
            return
        }

        if hasSharedItemsWithoutPeople {
            completion(.failure(.insertFailed("Select at least one person for each shared item.")))
            return
        }

        delegate?.didStartCreatingTransactions()

        let mappings = columnMappingService.loadDatabaseMappings()
        guard let expenseMapping = mappings.values.first(where: { $0.role == .expense && $0.columnMapping != nil }),
              let columnMapping = expenseMapping.columnMapping else {
            completion(.failure(.noExpenseDatabase))
            return
        }
        guard let databaseId = mappings.values.first(where: { $0.role == .expense })?.databaseId else {
            completion(.failure(.noDatabaseId))
            return
        }

        if hasSharedItems {
            createCombinedTransaction(databaseId: databaseId, columnMapping: columnMapping, expenseMapping: expenseMapping, completion: completion)
        } else {
            createPersonalTransaction(databaseId: databaseId, columnMapping: columnMapping, expenseMapping: expenseMapping, completion: completion)
        }
    }

    /// Creates one combined receipt expense with version 2 split metadata.
    private func createCombinedTransaction(databaseId: String, columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData, completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        let settlement = multiPersonSettlement
        let amount = settlement.myShare
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) Receipt"

        var values = buildCoreValues(title: title, amount: amount, date: date, columnMapping: columnMapping, expenseMapping: expenseMapping)

        if let amountCol = columnMapping.amountColumn {
            for i in values.indices where values[i].propertyName == amountCol {
                values[i].numberValue = amount
            }
        }

        let paidAmount = includedTotal
        let receiptMeta = ReceiptScanMetadata(
            source: "geminiReceiptScan",
            merchant: merchant,
            itemCount: items.count,
            originalTotal: receiptResult.summary.totalCharged ?? receiptResult.summary.total
        )

        if let metadataCol = columnMapping.expenseAppMetadataProperty {
            let metaJSON = buildMultiPersonSplitMetadataJSON(paidAmount: paidAmount, myShare: settlement.myShare, theyOwe: settlement.theyOwe, personOwes: settlement.personOwes, receiptMeta: receiptMeta)
            var metaValue = DynamicFormValue(propertyName: metadataCol, propertyType: .richText)
            metaValue.stringValue = metaJSON
            values.append(metaValue)
        }

        appendCategoryValue(&values, columnMapping: columnMapping, expenseMapping: expenseMapping)

        TransactionInsertService.shared.insertTransaction(databaseId: databaseId, values: values, token: token) { [weak self] result in
            switch result {
            case .success(let page):
                guard let self = self else { return }
                let people = SplitPeopleStore.shared.getPeople()
                let splitWithStr = settlement.personOwes.keys.compactMap { pid in
                    people.first(where: { $0.id == pid })?.name
                }.joined(separator: ", ")
                let splitMeta = SplitMetadata(
                    enabled: true,
                    paidAmount: paidAmount,
                    myShare: settlement.myShare,
                    theyOwe: settlement.theyOwe,
                    type: "receiptMultiPerson",
                    status: "pending",
                    splitWith: splitWithStr.isEmpty ? nil : splitWithStr,
                    inputs: nil
                )
                let tx = NormalizedTransaction(
                    id: page.id,
                    title: title,
                    amount: abs(amount),
                    paidAmount: paidAmount,
                    category: self.selectedCategoryName,
                    date: date,
                    databaseId: databaseId,
                    databaseRole: .expense,
                    rawProperties: page.properties,
                    splitMetadata: splitMeta
                )
                SessionCacheManager.shared.addExpense(tx)
                completion(.success(()))
            case .failure(let e):
                completion(.failure(.insertFailed(e.localizedDescription)))
            }
        }
    }

    private func createPersonalTransaction(databaseId: String, columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData, completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        let amount = personalTotal
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) Receipt"

        var values = buildCoreValues(title: title, amount: amount, date: date, columnMapping: columnMapping, expenseMapping: expenseMapping)
        appendCategoryValue(&values, columnMapping: columnMapping, expenseMapping: expenseMapping)

        TransactionInsertService.shared.insertTransaction(databaseId: databaseId, values: values, token: token) { [weak self] result in
            switch result {
            case .success(let page):
                guard let self = self else { return }
                let tx = NormalizedTransaction(
                    id: page.id,
                    title: title,
                    amount: abs(amount),
                    paidAmount: nil,
                    category: self.selectedCategoryName,
                    date: date,
                    databaseId: databaseId,
                    databaseRole: .expense,
                    rawProperties: page.properties,
                    splitMetadata: nil
                )
                SessionCacheManager.shared.addExpense(tx)
                completion(.success(()))
            case .failure(let e):
                completion(.failure(.insertFailed(e.localizedDescription)))
            }
        }
    }

    /// Build title, amount, date form values
    private func buildCoreValues(title: String, amount: Double, date: Date, columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData) -> [DynamicFormValue] {
        var values: [DynamicFormValue] = []
        if let titleCol = columnMapping.titleColumn {
            var v = DynamicFormValue(propertyName: titleCol, propertyType: .title)
            v.stringValue = title
            values.append(v)
        }
        if let amountCol = columnMapping.amountColumn {
            var v = DynamicFormValue(propertyName: amountCol, propertyType: .number)
            v.numberValue = amount
            values.append(v)
        }
        if let dateCol = columnMapping.dateColumn {
            var v = DynamicFormValue(propertyName: dateCol, propertyType: .date)
            v.dateValue = date
            values.append(v)
        }
        return values
    }

    /// Append category value with correct property type and relation IDs
    private func appendCategoryValue(_ values: inout [DynamicFormValue], columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData) {
        guard let catCol = columnMapping.categoryColumn else { return }

        let isRelation = isRelationCategoryField

        if isRelation {
            guard let id = selectedCategoryId else { return }
            print("[ReceiptReview] Appending category as relation: id=\(id)")
            var catValue = DynamicFormValue(propertyName: catCol, propertyType: .relation)
            catValue.relationIds = [id]
            values.append(catValue)
        } else if categoryColumnType == "select" || categoryColumnType == "status" {
            guard let name = selectedCategoryName else { return }
            print("[ReceiptReview] Appending category as \(categoryColumnType): \(name)")
            var catValue = DynamicFormValue(propertyName: catCol, propertyType: .select)
            if categoryColumnType == "status" {
                catValue.propertyType = .status
            }
            catValue.selectValue = name
            values.append(catValue)
        }
    }

    // MARK: - Split Metadata JSON

    /// Build version 2 split metadata JSON for multi-person receipt splits.
    private func buildMultiPersonSplitMetadataJSON(paidAmount: Double, myShare: Double, theyOwe: Double, personOwes: [String: Double], receiptMeta: ReceiptScanMetadata) -> String {
        let people = SplitPeopleStore.shared.getPeople()
        let participants: [[String: Any]] = personOwes.compactMap { pid, owes in
            guard let person = people.first(where: { $0.id == pid }) else { return nil }
            return [
                "id": pid,
                "name": person.name,
                "owes": owes
            ]
        }

        let itemsJSON: [[String: Any]] = receiptResult.items.map { item in
            [
                "name": item.name,
                "price": item.finalPrice,
                "assignment": item.classification.rawValue,
                "sharedWith": item.sharedWith
            ]
        }

        var data: [String: Any] = [:]
        data["version"] = 2
        data["split"] = [
            "enabled": true,
            "status": "pending",
            "type": "receiptMultiPerson",
            "paidAmount": paidAmount,
            "myShare": myShare,
            "theyOwe": theyOwe,
            "splitWith": NSNull(),
            "participants": participants,
            "items": itemsJSON,
            "inputs": [:]
        ] as [String: Any]
        if let metaData = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(receiptMeta)) as? [String: Any] {
            data["receipt"] = metaData
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return "" }
        return jsonString
    }
}
