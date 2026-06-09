import Foundation

enum ReceiptReviewError: LocalizedError {
    case noExpenseDatabase
    case noDatabaseId
    case noItemsToCreate
    case insertFailed(String)

    var errorDescription: String? {
        switch self {
        case .noExpenseDatabase: return "No expense database configured."
        case .noDatabaseId: return "No expense database ID found."
        case .noItemsToCreate: return "No items to create."
        case .insertFailed(let msg): return "Insert failed: \(msg)"
        }
    }
}

protocol ReceiptReviewViewModelDelegate: AnyObject {
    func didUpdateSummary()
    func didStartCreatingTransactions()
    func didCreateTransactions()
    func didFailWithError(_ error: String)
}

final class ReceiptReviewViewModel {

    weak var delegate: ReceiptReviewViewModelDelegate?

    private(set) var parseResult: ReceiptParseResult

    var merchantName: String {
        get { parseResult.merchantName ?? "" }
        set { parseResult.merchantName = newValue }
    }

    var receiptDate: Date? {
        get { parseResult.date }
        set { parseResult.date = newValue }
    }

    var items: [ReceiptItem] {
        parseResult.items
    }

    var warnings: [String] {
        parseResult.warnings
    }

    var hasWarnings: Bool {
        !parseResult.warnings.isEmpty
    }

    var includeTaxProportionally: Bool = true

    var splitMethod: SplitMethodType = .splitEqually

    private(set) var personalCategoryName: String?
    private(set) var sharedCategoryName: String?
    private var categorySuggestions: [String] = []

    private let token: String
    private let columnMappingService = ColumnMappingService.shared

    init(parseResult: ReceiptParseResult, token: String) {
        self.parseResult = parseResult
        self.token = token
        suggestCategories()
    }

    // MARK: - Item Management

    func updateItem(_ item: ReceiptItem) {
        if let idx = parseResult.items.firstIndex(where: { $0.id == item.id }) {
            parseResult.items[idx] = item
            delegate?.didUpdateSummary()
        }
    }

    func setClassification(for itemId: String, classification: ReceiptItemClassification) {
        if let idx = parseResult.items.firstIndex(where: { $0.id == itemId }) {
            parseResult.items[idx].classification = classification
            delegate?.didUpdateSummary()
        }
    }

    func updateItemName(itemId: String, name: String) {
        if let idx = parseResult.items.firstIndex(where: { $0.id == itemId }) {
            parseResult.items[idx].name = name
            delegate?.didUpdateSummary()
        }
    }

    func updateItemPrice(itemId: String, price: Double) {
        if let idx = parseResult.items.firstIndex(where: { $0.id == itemId }) {
            parseResult.items[idx].price = price
            delegate?.didUpdateSummary()
        }
    }

    func deleteItem(itemId: String) {
        parseResult.items.removeAll { $0.id == itemId }
        delegate?.didUpdateSummary()
    }

    func addItem(name: String, price: Double) {
        let item = ReceiptItem(
            id: UUID().uuidString,
            rawText: name,
            name: name,
            price: price,
            classification: .mine,
            confidence: 1.0,
            isEditable: true
        )
        parseResult.items.append(item)
        delegate?.didUpdateSummary()
    }

    func setPersonalCategory(_ name: String?) {
        personalCategoryName = name
    }

    func setSharedCategory(_ name: String?) {
        sharedCategoryName = name
    }

    // MARK: - Summary Calculations

    var personalTotal: Double {
        let mineItems = parseResult.items
            .filter { $0.classification == .mine }
            .reduce(0) { $0 + $1.price }
        if includeTaxProportionally, let tax = parseResult.tax, tax > 0 {
            let allTotal = parseResult.items
                .filter { $0.classification != .ignore }
                .reduce(0) { $0 + $1.price }
            if allTotal > 0 {
                return mineItems + (mineItems / allTotal) * tax
            }
        }
        return mineItems
    }

    var sharedTotal: Double {
        let sharedItems = parseResult.items
            .filter { $0.classification == .shared }
            .reduce(0) { $0 + $1.price }
        if includeTaxProportionally, let tax = parseResult.tax, tax > 0 {
            let allTotal = parseResult.items
                .filter { $0.classification != .ignore }
                .reduce(0) { $0 + $1.price }
            if allTotal > 0 {
                return sharedItems + (sharedItems / allTotal) * tax
            }
        }
        return sharedItems
    }

    var myShare: Double {
        guard sharedTotal > 0 else { return 0 }
        let result = SplitCalculator.calculate(paidAmount: sharedTotal, method: splitMethod)
        return result.myShare
    }

    var theyOwe: Double {
        guard sharedTotal > 0 else { return 0 }
        let result = SplitCalculator.calculate(paidAmount: sharedTotal, method: splitMethod)
        return result.theyOwe
    }

    var totalCounted: Double {
        personalTotal + myShare
    }

    var hasPersonalItems: Bool {
        parseResult.items.contains { $0.classification == .mine }
    }

    var hasSharedItems: Bool {
        parseResult.items.contains { $0.classification == .shared }
    }

    var hasTax: Bool {
        if let tax = parseResult.tax, tax > 0 { return true }
        return false
    }

    var taxAmount: Double {
        parseResult.tax ?? 0
    }

    // MARK: - Transaction Creation

    func createTransactions(completion: @escaping (Result<Void, ReceiptReviewError>) -> Void) {
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

        // A: Personal transaction
        if hasPersonalItems {
            group.enter()
            createPersonalTransaction(
                databaseId: databaseId,
                columnMapping: columnMapping,
                expenseMapping: expenseMapping
            ) { result in
                switch result {
                case .success:
                    createCount += 1
                case .failure(let error):
                    lastError = error
                }
                group.leave()
            }
        }

        // B: Shared transaction
        if hasSharedItems {
            group.enter()
            createSharedTransaction(
                databaseId: databaseId,
                columnMapping: columnMapping,
                expenseMapping: expenseMapping
            ) { result in
                switch result {
                case .success:
                    createCount += 1
                case .failure(let error):
                    lastError = error
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

    private func createPersonalTransaction(
        databaseId: String,
        columnMapping: ColumnMapping,
        expenseMapping: DatabaseMappingData,
        completion: @escaping (Result<Void, ReceiptReviewError>) -> Void
    ) {
        let personalAmount = self.personalTotal
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) - Personal"

        var values = buildCoreValues(
            title: title,
            amount: personalAmount,
            date: date,
            columnMapping: columnMapping,
            expenseMapping: expenseMapping
        )

        // Add category for personal
        if let cat = personalCategoryName, let catCol = columnMapping.categoryColumn {
            var catValue = DynamicFormValue(propertyName: catCol, propertyType: .date)
            if let mappingType = findCategoryPropertyType(expenseMapping: expenseMapping) {
                catValue.propertyType = mappingType
                catValue.selectValue = cat
            }
            values.append(catValue)
        }

        TransactionInsertService.shared.insertTransaction(
            databaseId: databaseId,
            values: values,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let page):
                let normalizer = TransactionNormalizer.shared
                let txs = normalizer.normalize(rows: [page], mapping: expenseMapping, role: .expense)
                if let tx = txs.first {
                    SessionCacheManager.shared.addExpense(tx)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(.insertFailed(error.localizedDescription)))
            }
        }
    }

    private func createSharedTransaction(
        databaseId: String,
        columnMapping: ColumnMapping,
        expenseMapping: DatabaseMappingData,
        completion: @escaping (Result<Void, ReceiptReviewError>) -> Void
    ) {
        let sharedAmount = self.sharedTotal
        let myShareAmount = self.myShare
        let theyOweAmount = self.theyOwe
        let date = receiptDate ?? Date()
        let merchant = merchantName.isEmpty ? "Receipt" : merchantName
        let title = "\(merchant) - Shared"

        var values = buildCoreValues(
            title: title,
            amount: myShareAmount,
            date: date,
            columnMapping: columnMapping,
            expenseMapping: expenseMapping
        )

        // Override amount column with myShare
        if let amountCol = columnMapping.amountColumn {
            for i in values.indices {
                if values[i].propertyName == amountCol {
                    values[i].numberValue = myShareAmount
                }
            }
        }

        // Add split metadata JSON
        let receiptMeta = ReceiptScanMetadata(
            source: "receiptScan",
            merchant: merchant,
            itemCount: items.count,
            originalTotal: parseResult.total
        )

        if let metadataCol = columnMapping.expenseAppMetadataProperty {
            let metadataJSON = buildSplitMetadataJSON(
                paidAmount: sharedAmount,
                myShare: myShareAmount,
                theyOwe: theyOweAmount,
                status: "pending",
                receiptMeta: receiptMeta
            )
            var metaValue = DynamicFormValue(propertyName: metadataCol, propertyType: .richText)
            metaValue.stringValue = metadataJSON
            values.append(metaValue)
        }

        // Add category for shared
        if let cat = sharedCategoryName ?? personalCategoryName,
           let catCol = columnMapping.categoryColumn {
            var catValue = DynamicFormValue(propertyName: catCol, propertyType: .date)
            if let mappingType = findCategoryPropertyType(expenseMapping: expenseMapping) {
                catValue.propertyType = mappingType
                catValue.selectValue = cat
            }
            values.append(catValue)
        }

        TransactionInsertService.shared.insertTransaction(
            databaseId: databaseId,
            values: values,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let page):
                let normalizer = TransactionNormalizer.shared
                let txs = normalizer.normalize(rows: [page], mapping: expenseMapping, role: .expense)
                if let tx = txs.first {
                    SessionCacheManager.shared.addExpense(tx)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(.insertFailed(error.localizedDescription)))
            }
        }
    }

    private func buildCoreValues(
        title: String,
        amount: Double,
        date: Date,
        columnMapping: ColumnMapping,
        expenseMapping: DatabaseMappingData
    ) -> [DynamicFormValue] {
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

    private func buildSplitMetadataJSON(
        paidAmount: Double,
        myShare: Double,
        theyOwe: Double,
        status: String,
        receiptMeta: ReceiptScanMetadata?
    ) -> String {
        var data: [String: Any] = [:]
        data["version"] = 1
        data["split"] = [
            "enabled": true,
            "paidAmount": paidAmount,
            "myShare": myShare,
            "theyOwe": theyOwe,
            "type": splitMethod.rawValue,
            "status": status,
            "splitWith": NSNull(),
            "inputs": [:]
        ] as [String: Any]

        if let meta = receiptMeta,
           let metaData = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(meta)) as? [String: Any] {
            data["receipt"] = metaData
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }

    private func findCategoryPropertyType(expenseMapping: DatabaseMappingData) -> NotionPropertyType? {
        let mappings = columnMappingService.loadDatabaseMappings()
        guard let dbId = mappings.values.first(where: { $0.role == .expense })?.databaseId else { return nil }
        guard let catCol = expenseMapping.columnMapping?.categoryColumn else { return nil }
        let catTypeStr = expenseMapping.categoryType ?? "select"
        return NotionPropertyType(rawValue: catTypeStr)
    }

    private func suggestCategories() {
        guard let merchant = parseResult.merchantName?.lowercased() else { return }
        let engine = ExpenseCategorySuggestionEngine()
        let suggestions = engine.suggestions(for: merchant)
        categorySuggestions = suggestions.map { $0.displayName }
        personalCategoryName = categorySuggestions.first
        sharedCategoryName = categorySuggestions.first
    }
}
