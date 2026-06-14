//
//  TransactionDetailViewController.swift
//  Notra
//

import UIKit

class TransactionDetailViewController: UIViewController {

    private let transaction: NormalizedTransaction
    private var mappedColumnNames = Set<String>()

    var onEdit: ((NormalizedTransaction) -> Void)?
    var onDelete: ((NormalizedTransaction) -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = UIView()
    private let typeBadge = UILabel()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let detailsStack = UIStackView()
    private var splitContainer: UIView?
    private let buttonStack = UIStackView()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    // Tracks relation rows whose titles need async resolution
    private var relationRowViews: [String: DetailRowView] = [:]
    private var relationIdsByProperty: [String: [String]] = [:]

    init(transaction: NormalizedTransaction) {
        self.transaction = transaction
        super.init(nibName: nil, bundle: nil)
        if let mapping = ColumnMappingService.shared.loadDatabaseMappings()[transaction.databaseId]?.columnMapping {
            var names = [mapping.titleColumn, mapping.amountColumn, mapping.dateColumn, mapping.categoryColumn].compactMap { $0 }
            if let metadataCol = mapping.expenseAppMetadataProperty {
                names.append(metadataCol)
            }
            mappedColumnNames = Set(names)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        resolvePendingRelations()
    }

    private func setupView() {
        view.backgroundColor = AppTheme.Colors.background

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = AppTheme.Colors.textMuted
        navigationItem.rightBarButtonItem = closeButton

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        setupHeader()
        setupDetails()
        setupSplitDetails()
        setupButtons()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = AppTheme.Colors.cardBackground
        headerView.layer.cornerRadius = AppTheme.CornerRadius.card
        if AppTheme.currentMode == .dark {
            headerView.layer.borderWidth = 1
            headerView.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        headerView.layer.shadowColor = AppTheme.activePalette.shadow.cgColor
        headerView.layer.shadowOpacity = 0.15
        headerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        headerView.layer.shadowRadius = 6
        headerView.layer.masksToBounds = false
        contentView.addSubview(headerView)

        let isExpense = transaction.databaseRole == .expense
        let tintColor = isExpense ? AppTheme.Colors.expense : AppTheme.Colors.income

        typeBadge.text = isExpense ? "Expense" : "Income"
        typeBadge.font = AppTheme.Fonts.smallMedium
        typeBadge.textColor = .white
        typeBadge.backgroundColor = tintColor
        typeBadge.textAlignment = .center
        typeBadge.layer.cornerRadius = 10
        typeBadge.layer.masksToBounds = true
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(typeBadge)

        titleLabel.text = transaction.title
        titleLabel.font = AppTheme.Fonts.headingMediumRounded
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let sign = isExpense ? "−" : "+"
        amountLabel.text = "\(sign)\(Self.currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00")"
        amountLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        amountLabel.textColor = tintColor
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(amountLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            typeBadge.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            typeBadge.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            typeBadge.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: typeBadge.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            amountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            amountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            amountLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            amountLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20)
        ])
    }

    private func setupDetails() {
        detailsStack.axis = .vertical
        detailsStack.spacing = 0
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        detailsStack.backgroundColor = AppTheme.Colors.cardBackground
        detailsStack.layer.cornerRadius = AppTheme.CornerRadius.card
        if AppTheme.currentMode == .dark {
            detailsStack.layer.borderWidth = 1
            detailsStack.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        detailsStack.clipsToBounds = true
        contentView.addSubview(detailsStack)

        var detailRows: [(label: String, value: String)] = []

        detailRows.append(("Date", transaction.formattedDate))

        if let category = transaction.category, !category.isEmpty {
            detailRows.append(("Category", category))
        }

        if let raw = transaction.rawProperties {
            for (name, prop) in raw {
                guard let typeStr = prop.type else { continue }
                if NotionPropertyType.isReadOnly(typeStr) { continue }
                if mappedColumnNames.contains(name) { continue }
                if let display = displayValue(for: prop, propertyName: name, type: typeStr) {
                    detailRows.append((name, display))
                    if typeStr == "relation", let rel = prop.relation {
                        let ids = rel.compactMap { $0.id }
                        relationIdsByProperty[name] = ids
                    }
                }
            }
        }

        for (label, value) in detailRows {
            let row = DetailRowView(label: label, value: value)
            detailsStack.addArrangedSubview(row)
            if label != detailRows.last?.label {
                let separator = UIView()
                separator.backgroundColor = AppTheme.Colors.border.withAlphaComponent(0.4)
                separator.translatesAutoresizingMaskIntoConstraints = false
                detailsStack.addArrangedSubview(separator)
                separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            }
            if relationIdsByProperty[label] != nil {
                relationRowViews[label] = row
            }
        }

        NSLayoutConstraint.activate([
            detailsStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            detailsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    private func setupSplitDetails() {
        guard transaction.isSplit else { return }

        let splitContainer = UIView()
        splitContainer.backgroundColor = AppTheme.Colors.cardBackground
        splitContainer.layer.cornerRadius = AppTheme.CornerRadius.card
        if AppTheme.currentMode == .dark {
            splitContainer.layer.borderWidth = 1
            splitContainer.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        splitContainer.clipsToBounds = true
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitContainer)
        self.splitContainer = splitContainer

        let headerLabel = UILabel()
        headerLabel.text = "Split Details"
        headerLabel.font = AppTheme.Fonts.captionBold
        headerLabel.textColor = AppTheme.Colors.textPrimary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(headerLabel)

        let overallStack = UIStackView()
        overallStack.axis = .vertical
        overallStack.spacing = 12
        overallStack.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(overallStack)

        let countedStr = Self.currencyFormatter.string(from: NSNumber(value: transaction.effectiveAmount)) ?? "$0"
        let paidStr = Self.currencyFormatter.string(from: NSNumber(value: transaction.paidAmount ?? transaction.effectiveAmount)) ?? "$0"
        let owedStr = Self.currencyFormatter.string(from: NSNumber(value: transaction.reimbursementAmount)) ?? "$0"
        let statusValue = transaction.splitStatus?.capitalized ?? "Pending"

        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually

        let countedTile = makeStatTile(label: "Counted", value: countedStr)
        let paidTile = makeStatTile(label: "Paid", value: paidStr)
        row1.addArrangedSubview(countedTile)
        row1.addArrangedSubview(paidTile)
        overallStack.addArrangedSubview(row1)

        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 12
        row2.distribution = .fillEqually

        let owedTile = makeStatTile(label: "Owed", value: owedStr)
        let statusTile = makeStatTile(label: "Status", value: statusValue)
        row2.addArrangedSubview(owedTile)
        row2.addArrangedSubview(statusTile)
        overallStack.addArrangedSubview(row2)

        if let type = transaction.splitMetadata?.displayTypeName {
            let methodRow = UILabel()
            methodRow.text = "Method: \(type)"
            methodRow.font = AppTheme.Fonts.body
            methodRow.textColor = AppTheme.Colors.textSecondary
            methodRow.translatesAutoresizingMaskIntoConstraints = false
            overallStack.addArrangedSubview(methodRow)
        }

        if let splitWith = transaction.splitWith, !splitWith.isEmpty {
            let splitWithRow = UILabel()
            splitWithRow.text = "Split with: \(splitWith)"
            splitWithRow.font = AppTheme.Fonts.body
            splitWithRow.textColor = AppTheme.Colors.textSecondary
            splitWithRow.translatesAutoresizingMaskIntoConstraints = false
            overallStack.addArrangedSubview(splitWithRow)
        }

        // Phase 2: Multi-person split breakdown
        if let split = transaction.splitMetadata, split.isMultiPersonReceipt || split.isManualMultiPerson {
            overallStack.addArrangedSubview(makeSectionSeparator())

            // Participants
            if let participants = split.participants, !participants.isEmpty {
                let peopleHeader = UILabel()
                peopleHeader.text = "People"
                peopleHeader.font = AppTheme.Fonts.captionBold
                peopleHeader.textColor = AppTheme.Colors.textPrimary
                overallStack.addArrangedSubview(peopleHeader)

                for p in participants {
                    let name = p.name
                    let owes = Self.currencyFormatter.string(from: NSNumber(value: p.owes)) ?? "$0.00"
                    let row = makeDetailRow(label: name, value: "Owes: \(owes)")
                    overallStack.addArrangedSubview(row)
                }
            }

            // Items
            if let items = split.items, !items.isEmpty {
                overallStack.addArrangedSubview(makeSectionSeparator())

                let itemsHeader = UILabel()
                itemsHeader.text = "Items"
                itemsHeader.font = AppTheme.Fonts.captionBold
                itemsHeader.textColor = AppTheme.Colors.textPrimary
                overallStack.addArrangedSubview(itemsHeader)

                let participants = split.participants ?? []

                for item in items {
                    let priceStr = Self.currencyFormatter.string(from: NSNumber(value: item.price)) ?? "$0.00"
                    let assignmentStr: String
                    switch item.assignment {
                    case "mine":
                        assignmentStr = "Mine"
                    case "shared":
                        let names = item.sharedWith.compactMap { pid in
                            participants.first(where: { $0.id == pid })?.name ?? "Unknown person"
                        }
                        if names.isEmpty {
                            assignmentStr = "Shared"
                        } else {
                            assignmentStr = "Shared with \(names.joined(separator: ", "))"
                        }
                    case "ignore":
                        assignmentStr = "Ignored"
                    default:
                        assignmentStr = item.assignment.capitalized
                    }
                    let row = makeDetailRow(label: item.name, value: "\(priceStr) — \(assignmentStr)")
                    overallStack.addArrangedSubview(row)
                }
            }

            // Receipt metadata
            if let meta = split.receiptMetadata {
                overallStack.addArrangedSubview(makeSectionSeparator())

                let receiptHeader = UILabel()
                receiptHeader.text = "Receipt"
                receiptHeader.font = AppTheme.Fonts.captionBold
                receiptHeader.textColor = AppTheme.Colors.textPrimary
                overallStack.addArrangedSubview(receiptHeader)

                if let merchant = meta.merchant, !merchant.isEmpty {
                    overallStack.addArrangedSubview(makeDetailRow(label: "Merchant", value: merchant))
                }
                overallStack.addArrangedSubview(makeDetailRow(label: "Items", value: "\(meta.itemCount)"))
            }
        }

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: detailsStack.bottomAnchor, constant: 16),
            splitContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            splitContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            headerLabel.topAnchor.constraint(equalTo: splitContainer.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor, constant: -16),

            overallStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 12),
            overallStack.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor, constant: 16),
            overallStack.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor, constant: -16),
            overallStack.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor, constant: -16)
        ])
    }

    private func makeSectionSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = AppTheme.Colors.border.withAlphaComponent(0.3)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }

    private func makeDetailRow(label: String, value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.font = AppTheme.Fonts.body
        labelLabel.textColor = AppTheme.Colors.textPrimary
        labelLabel.numberOfLines = 0
        labelLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.Fonts.body
        valueLabel.textColor = AppTheme.Colors.textSecondary
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(labelLabel)
        row.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            labelLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            labelLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),
            labelLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),

            valueLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4)
        ])

        return row
    }

    private func makeStatTile(label: String, value: String) -> UIView {
        let tile = UIView()
        tile.backgroundColor = AppTheme.Colors.cardBackground
        tile.layer.cornerRadius = 10
        tile.layer.borderWidth = 1
        tile.layer.borderColor = AppTheme.Colors.border.withAlphaComponent(AppTheme.currentMode == .dark ? 0.4 : 0.25).cgColor
        tile.translatesAutoresizingMaskIntoConstraints = false

        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.font = AppTheme.Fonts.small
        labelLabel.textColor = AppTheme.Colors.textMuted
        labelLabel.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(labelLabel)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            labelLabel.topAnchor.constraint(equalTo: tile.topAnchor, constant: 10),
            labelLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 12),
            labelLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -12),

            valueLabel.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -10)
        ])

        return tile
    }

    private func separatorView() -> UIView {
        let separator = UIView()
        separator.backgroundColor = AppTheme.Colors.border.withAlphaComponent(0.4)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return separator
    }

    private func setupButtons() {
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStack)

        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = AppTheme.Fonts.buttonLarge
        editButton.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
        editButton.backgroundColor = AppTheme.Colors.secondaryBrown
        editButton.layer.cornerRadius = AppTheme.CornerRadius.medium
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(editButton)

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.titleLabel?.font = AppTheme.Fonts.buttonLarge
        deleteButton.setTitleColor(.white, for: .normal)
        let isExpense = transaction.databaseRole == .expense
        deleteButton.backgroundColor = isExpense ? AppTheme.Colors.expense : AppTheme.Colors.income
        deleteButton.layer.cornerRadius = AppTheme.CornerRadius.medium
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(deleteButton)

        let buttonTopAnchor: NSLayoutYAxisAnchor
        if let splitContainer = splitContainer {
            buttonTopAnchor = splitContainer.bottomAnchor
        } else {
            buttonTopAnchor = detailsStack.bottomAnchor
        }

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: buttonTopAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func resolvePendingRelations() {
        guard let token = UserDefaultsManager.shared.notionToken else { return }

        for (propertyName, ids) in relationIdsByProperty {
            guard !ids.isEmpty, let rowView = relationRowViews[propertyName] else { continue }

            let cached = SessionCacheManager.shared.resolveRelationTitles(pageIds: ids)
            if !cached.isEmpty {
                rowView.setValue(cached.joined(separator: ", "))
                continue
            }

            RelationResolverService.shared.resolveRelationTitles(pageIds: ids, token: token) { [weak self] result in
                guard let self = self else { return }
                if case .success(let titles) = result {
                    let joined = titles.joined(separator: ", ")
                    if !joined.isEmpty {
                        self.relationRowViews[propertyName]?.setValue(joined)
                    }
                }
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func editTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onEdit?(self.transaction)
        }
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(
            title: "Delete Transaction?",
            message: "This will move the transaction to trash in Notion.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                self.onDelete?(self.transaction)
            }
        })
        present(alert, animated: true)
    }

    private func displayValue(for prop: NotionPropertyValue, propertyName: String, type: String) -> String? {
        switch type {
        case "title":
            return prop.title?.compactMap { $0.plainText ?? $0.text?.content }.joined()
        case "rich_text":
            return prop.richText?.compactMap { $0.plainText ?? $0.text?.content }.joined()
        case "number":
            guard let n = prop.number else { return nil }
            return Self.currencyFormatter.string(from: NSNumber(value: n))
        case "select", "status":
            return prop.select?.name
        case "multi_select":
            guard let ms = prop.multiSelect, !ms.isEmpty else { return nil }
            return ms.compactMap { $0.name }.joined(separator: ", ")
        case "date":
            guard let start = prop.date?.start else { return nil }
            let parts = start.prefix(10).split(separator: "-")
            if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
                var comps = DateComponents()
                comps.year = y; comps.month = m; comps.day = d
                if let date = Calendar.current.date(from: comps) {
                    return Self.dateFormatter.string(from: date)
                }
            }
            return String(start.prefix(10))
        case "checkbox":
            guard let b = prop.checkbox else { return nil }
            return b ? "Yes" : "No"
        case "url":
            return prop.url
        case "email":
            return prop.email
        case "phone_number":
            return prop.phoneNumber
        case "relation":
            guard let rel = prop.relation, !rel.isEmpty else { return nil }
            let relationIds = rel.compactMap { $0.id }
            if let targetDbIds = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: transaction.databaseId),
               let targetDbId = targetDbIds[propertyName],
               let targetData = SessionCacheManager.shared.getRelationTargetData(databaseId: targetDbId) {
                let titles = relationIds.compactMap { targetData[$0] }.filter { !$0.isEmpty }
                if !titles.isEmpty { return titles.joined(separator: ", ") }
            }
            let titles = SessionCacheManager.shared.resolveRelationTitles(pageIds: relationIds)
            if !titles.isEmpty { return titles.joined(separator: ", ") }
            return relationIds.joined(separator: ", ")
        default:
            return nil
        }
    }
}

// MARK: - Detail Row View

private class DetailRowView: UIView {
    private let labelLabel = UILabel()
    private let valueLabel = UILabel()

    var currentValue: String { valueLabel.text ?? "" }

    init(label: String, value: String) {
        super.init(frame: .zero)
        setup(label: label, value: value)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }

    private func setup(label: String, value: String) {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        labelLabel.text = label
        labelLabel.font = AppTheme.Fonts.captionBold
        labelLabel.textColor = AppTheme.Colors.textMuted
        labelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelLabel)

        valueLabel.text = value
        valueLabel.font = AppTheme.Fonts.body
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            labelLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            labelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            labelLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            valueLabel.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}
