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

    // Backwards-compatible accessors for ReceiptSummaryCardCell
    var receiptSubtotal: Double? { receiptResult.summary.itemsSubtotal }
    var receiptTax: Double? { receiptResult.summary.tax }
    var receiptDeliveryFee: Double? { receiptResult.summary.deliveryFee }
    var receiptDeliveryCharged: Double? { nil }
    var receiptTip: Double? { receiptResult.summary.tip }
    var receiptTotal: Double? { receiptResult.summary.totalCharged ?? receiptResult.summary.total }

    // Kept for backward compat with ReceiptSummaryCardCell check
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

        // First, suggest a category from merchant name using engine
        if let merchant = receiptResult.merchant {
            let engine = ExpenseCategorySuggestionEngine()
            let suggestions = engine.suggestions(for: merchant)
            suggestedCategoryName = suggestions.first?.displayName
            if !isRelationCategoryField {
                selectCategory(id: suggestedCategoryName ?? "", name: suggestedCategoryName ?? "")
            }
        }

        if let dsId = columnMapping.categoryRelationDataSourceId {
            // Relation field: load actual options from the target database (Notion pages)
            isLoadingCategories = true
            transactionInsertService.loadRelationOptions(databaseId: dsId, token: token) { [weak self] result in
                // loadRelationOptions already dispatches to .main
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
        guard sharedTotal > 0 else { return 0 }
        return SplitCalculator.calculate(paidAmount: sharedTotal, method: splitMethod).myShare
    }

    var theyOwe: Double {
        guard sharedTotal > 0 else { return 0 }
        return SplitCalculator.calculate(paidAmount: sharedTotal, method: splitMethod).theyOwe
    }

    var totalCounted: Double { personalTotal + myShare }

    var hasPersonalItems: Bool { receiptResult.items.contains { $0.classification == .mine } }
    var hasSharedItems: Bool { receiptResult.items.contains { $0.classification == .shared } }

    var mineCount: Int {
        receiptResult.items.filter { $0.classification == .mine }.count
    }

    var sharedCount: Int {
        receiptResult.items.filter { $0.classification == .shared }.count
    }

    /// Relation categories require an explicit page ID selection.
    /// Non-relation (select/status) categories are optional — the suggested name is used if available.
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
        (mineCount + sharedCount > 0) && (!isCategoryRequired || selectedCategoryId != nil)
    }

    var createButtonTitle: String {
        let expenseCount = (hasPersonalItems ? 1 : 0) + (hasSharedItems ? 1 : 0)
        if expenseCount == 0 { return "Create Expenses" }
        return expenseCount == 1 ? "Create 1 Expense" : "Create 2 Expenses"
    }

    var helperText: String {
        if isCategoryRequired && selectedCategoryId == nil {
            return "Select a category to continue"
        }
        if mineCount + sharedCount == 0 {
            return "Mark items as Mine or Shared to create expenses"
        }
        return ""
    }

    // MARK: - Category Validation

    /// Whether the category column is backed by a Notion relation field that requires a page ID.
    /// Cached during loadCategoryOptions() — does NOT reload mappings on every access.
    var isRelationCategory: Bool { isRelationCategoryField }

    var isCategoryRequiredAndMissing: Bool {
        isRelationCategory && selectedCategoryId == nil
    }

    // MARK: - Transaction Creation

    func createTransactions(completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        // If this is a relation-type category, we ALWAYS require selection — even if options
        // haven't loaded yet. Otherwise the expense saves without a relation → "Uncategorized".
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

        var createCount = 0
        var lastError: ReceiptReviewError?
        let group = DispatchGroup()

        if hasPersonalItems {
            group.enter()
            createPersonalTransaction(databaseId: databaseId, columnMapping: columnMapping, expenseMapping: expenseMapping) { result in
                switch result {
                case .success: createCount += 1
                case .failure(let e): lastError = e
                }
                group.leave()
            }
        }
        if hasSharedItems {
            group.enter()
            createSharedTransaction(databaseId: databaseId, columnMapping: columnMapping, expenseMapping: expenseMapping) { result in
                switch result {
                case .success: createCount += 1
                case .failure(let e): lastError = e
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            if createCount > 0 {
                self?.delegate?.didCreateTransactions()
                completion(.success(()))
            } else if let error = lastError {
                self?.delegate?.didFailWithError(error.localizedDescription)
                completion(.failure(error))
            } else {
                self?.delegate?.didFailWithError("No items to create.")
                completion(.failure(.noItemsToCreate))
            }
        }
    }

    private func createPersonalTransaction(databaseId: String, columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData, completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        let amount = personalTotal
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) - Personal"

        var values = buildCoreValues(title: title, amount: amount, date: date, columnMapping: columnMapping, expenseMapping: expenseMapping)
        appendCategoryValue(&values, columnMapping: columnMapping, expenseMapping: expenseMapping)

        TransactionInsertService.shared.insertTransaction(databaseId: databaseId, values: values, token: token) { [weak self] result in
            switch result {
            case .success(let page):
                guard let self = self else { return }
                print("[ReceiptReview] Selected category before save: id=\(self.selectedCategoryId ?? "nil"), name=\(self.selectedCategoryName ?? "nil")")
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
                print("[SessionCache] Added transaction category: \(self.selectedCategoryName ?? "nil")")
                SessionCacheManager.shared.addExpense(tx)
                completion(.success(()))
            case .failure(let e):
                completion(.failure(.insertFailed(e.localizedDescription)))
            }
        }
    }

    private func createSharedTransaction(databaseId: String, columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData, completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
        let sharedAmt = sharedTotal
        let myShareAmt = myShare
        let theyOweAmt = theyOwe
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) - Shared"

        var values = buildCoreValues(title: title, amount: myShareAmt, date: date, columnMapping: columnMapping, expenseMapping: expenseMapping)

        if let amountCol = columnMapping.amountColumn {
            for i in values.indices where values[i].propertyName == amountCol {
                values[i].numberValue = myShareAmt
            }
        }

        let receiptMeta = ReceiptScanMetadata(
            source: "geminiReceiptScan",
            merchant: merchant,
            itemCount: items.count,
            originalTotal: receiptResult.summary.totalCharged ?? receiptResult.summary.total
        )

        if let metadataCol = columnMapping.expenseAppMetadataProperty {
            let metaJSON = buildSplitMetadataJSON(paidAmount: sharedAmt, myShare: myShareAmt, theyOwe: theyOweAmt, receiptMeta: receiptMeta)
            var metaValue = DynamicFormValue(propertyName: metadataCol, propertyType: .richText)
            metaValue.stringValue = metaJSON
            values.append(metaValue)
        }

        appendCategoryValue(&values, columnMapping: columnMapping, expenseMapping: expenseMapping)

        TransactionInsertService.shared.insertTransaction(databaseId: databaseId, values: values, token: token) { [weak self] result in
            switch result {
            case .success(let page):
                guard let self = self else { return }
                print("[ReceiptReview] Selected category before save: id=\(self.selectedCategoryId ?? "nil"), name=\(self.selectedCategoryName ?? "nil")")
                let splitMeta = SplitMetadata(
                    enabled: true,
                    paidAmount: sharedAmt,
                    myShare: myShareAmt,
                    theyOwe: theyOweAmt,
                    type: self.splitMethod.rawValue,
                    status: "pending",
                    splitWith: nil,
                    inputs: nil
                )
                let tx = NormalizedTransaction(
                    id: page.id,
                    title: title,
                    amount: abs(myShareAmt),
                    paidAmount: sharedAmt,
                    category: self.selectedCategoryName,
                    date: date,
                    databaseId: databaseId,
                    databaseRole: .expense,
                    rawProperties: page.properties,
                    splitMetadata: splitMeta
                )
                print("[SessionCache] Added transaction category: \(self.selectedCategoryName ?? "nil")")
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
    /// Append category value with correct property type and relation IDs
    /// Uses `categoryRelationDataSourceId` to detect relation type reliably.
    private func appendCategoryValue(_ values: inout [DynamicFormValue], columnMapping: ColumnMapping, expenseMapping: DatabaseMappingData) {
        guard let catCol = columnMapping.categoryColumn else { return }

        let isRelation = isRelationCategoryField

        if isRelation {
            // Relation type: use the page ID — if no ID selected, skip entirely
            // rather than sending an incorrect payload type.
            guard let id = selectedCategoryId else { return }
            print("[ReceiptReview] Appending category as relation: id=\(id)")
            var catValue = DynamicFormValue(propertyName: catCol, propertyType: .relation)
            catValue.relationIds = [id]
            values.append(catValue)
        } else if categoryColumnType == "select" || categoryColumnType == "status" {
            // Select/status: use the name directly
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

    private func buildSplitMetadataJSON(paidAmount: Double, myShare: Double, theyOwe: Double, receiptMeta: ReceiptScanMetadata) -> String {
        var data: [String: Any] = [:]
        data["version"] = 1
        data["split"] = [
            "enabled": true,
            "paidAmount": paidAmount,
            "myShare": myShare,
            "theyOwe": theyOwe,
            "type": splitMethod.rawValue,
            "status": "pending",
            "splitWith": NSNull(),
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
