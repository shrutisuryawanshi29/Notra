import UIKit

final class ReceiptReviewViewController: UIViewController {

    private let viewModel: ReceiptReviewViewModel
    private let token: String

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let createButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Create Expenses", for: .normal)
        b.backgroundColor = AppTheme.Colors.expense
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppTheme.Fonts.buttonLarge
        b.layer.cornerRadius = AppTheme.CornerRadius.button
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.setTitleColor(AppTheme.Colors.secondaryBrown, for: .normal)
        b.titleLabel?.font = AppTheme.Fonts.buttonMedium
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let loadingOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private var merchantField: UITextField?
    private var datePicker: UIDatePicker?
    private var includeTaxSwitch: UISwitch?

    init(parseResult: ReceiptParseResult, token: String) {
        self.viewModel = ReceiptReviewViewModel(parseResult: parseResult, token: token)
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        setupUI()
    }

    private func setupUI() {
        title = "Receipt Review"
        view.backgroundColor = AppTheme.Colors.background
        AppTheme.styleNavigationBar(navigationController?.navigationBar ?? UINavigationBar())

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HeaderCell")
        tableView.register(ReceiptItemCell.self, forCellReuseIdentifier: "ReceiptItemCell")
        tableView.register(SummaryCell.self, forCellReuseIdentifier: "SummaryCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.register(EditableFieldCell.self, forCellReuseIdentifier: "EditableFieldCell")
        tableView.register(ToggleCell.self, forCellReuseIdentifier: "ToggleCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(loadingOverlay)
        loadingOverlay.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func createTapped() {
        loadingOverlay.isHidden = false
        loadingIndicator.startAnimating()
        viewModel.createTransactions { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingOverlay.isHidden = true
                self?.loadingIndicator.stopAnimating()
                switch result {
                case .success:
                    let toast = ToastView(message: "Expenses created!")
                    toast.show(in: self?.view ?? UIView())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self?.dismiss(animated: true)
                    }
                case .failure(let error):
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func merchantChanged(_ field: UITextField) {
        viewModel.merchantName = field.text ?? ""
    }

    @objc private func dateChanged(_ picker: UIDatePicker) {
        viewModel.receiptDate = picker.date
    }

    @objc private func taxToggleChanged(_ sender: UISwitch) {
        viewModel.includeTaxProportionally = sender.isOn
        tableView.reloadSections(IndexSet(integer: 2), with: .none)
    }

    @objc private func addItemTapped() {
        let alert = UIAlertController(title: "Add Item", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Item name" }
        alert.addTextField { tf in tf.placeholder = "Price"; tf.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let priceStr = alert.textFields?[1].text?.replacingOccurrences(of: ",", with: "") ?? ""
            let price = Double(priceStr) ?? 0
            guard !name.isEmpty else { return }
            self?.viewModel.addItem(name: name, price: price)
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate

extension ReceiptReviewViewController: UITableViewDataSource, UITableViewDelegate {

    enum Section: Int, CaseIterable {
        case header
        case items
        case summary
        case categories
        case actions
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .header: return 1
        case .items: return viewModel.items.isEmpty ? 2 : viewModel.items.count + 1
        case .summary: return 1
        case .categories: return viewModel.hasTax ? 2 : 1
        case .actions: return 1
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .header:
            return configureHeaderCell(tableView, at: indexPath)
        case .items:
            if indexPath.row == 0 {
                return configureItemsHeaderCell(tableView, at: indexPath)
            }
            return configureItemCell(tableView, at: indexPath)
        case .summary:
            return configureSummaryCell(tableView, at: indexPath)
        case .categories:
            if viewModel.hasTax && indexPath.row == 0 {
                return configureTaxToggleCell(tableView, at: indexPath)
            }
            return configureActionsCell(tableView, at: indexPath)
        case .actions:
            return configureCreateCell(tableView, at: indexPath)
        case .none:
            return UITableViewCell()
        }
    }

    private func configureHeaderCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EditableFieldCell", for: indexPath) as! EditableFieldCell
        cell.configure(
            merchant: viewModel.merchantName,
            date: viewModel.receiptDate,
            warnings: viewModel.warnings
        )
        cell.onMerchantChange = { [weak self] text in
            self?.viewModel.merchantName = text
        }
        cell.onDateChange = { [weak self] date in
            self?.viewModel.receiptDate = date
        }
        return cell
    }

    private func configureItemsHeaderCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        cell.configure(title: "Add Item Manually", icon: "plus.circle")
        return cell
    }

    private func configureItemCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let itemIndex = indexPath.row - 1
        let item = viewModel.items[itemIndex]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiptItemCell", for: indexPath) as! ReceiptItemCell
        cell.configure(with: item)
        cell.onClassificationChange = { [weak self] classification in
            self?.viewModel.setClassification(for: item.id, classification: classification)
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
        }
        cell.onNameEdit = { [weak self] name in
            self?.viewModel.updateItemName(itemId: item.id, name: name)
        }
        cell.onPriceEdit = { [weak self] price in
            self?.viewModel.updateItemPrice(itemId: item.id, price: price)
        }
        cell.onDelete = { [weak self] in
            self?.viewModel.deleteItem(itemId: item.id)
            tableView.reloadData()
        }
        return cell
    }

    private func configureSummaryCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SummaryCell", for: indexPath) as! SummaryCell
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        cell.configure(
            personalTotal: viewModel.personalTotal,
            sharedTotal: viewModel.sharedTotal,
            myShare: viewModel.myShare,
            theyOwe: viewModel.theyOwe,
            totalCounted: viewModel.totalCounted,
            formatter: formatter,
            hasTax: viewModel.hasTax,
            taxAmount: viewModel.taxAmount,
            includeTax: viewModel.includeTaxProportionally
        )
        return cell
    }

    private func configureTaxToggleCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
        cell.configure(
            title: "Include Tax Proportionally",
            isOn: viewModel.includeTaxProportionally
        ) { [weak self] isOn in
            self?.viewModel.includeTaxProportionally = isOn
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
        }
        return cell
    }

    private func configureActionsCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        if viewModel.hasTax && !viewModel.includeTaxProportionally {
            cell.configure(title: "Tax excluded from items", icon: "info.circle")
        } else if viewModel.hasTax && viewModel.includeTaxProportionally {
            cell.configure(title: "Tax distributed proportionally", icon: "checkmark.circle")
        } else {
            cell.configure(title: "Split method: \(viewModel.splitMethod.chipLabel)", icon: "arrow.right.arrow.left")
        }
        return cell
    }

    private func configureCreateCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        let hasPersonal = viewModel.hasPersonalItems
        let hasShared = viewModel.hasSharedItems
        if hasPersonal && hasShared {
            cell.configure(title: "Create 2 Expenses (Personal + Shared)", icon: "checkmark.circle.fill", isAction: true)
        } else if hasPersonal {
            cell.configure(title: "Create 1 Personal Expense", icon: "checkmark.circle.fill", isAction: true)
        } else if hasShared {
            cell.configure(title: "Create 1 Shared Expense", icon: "checkmark.circle.fill", isAction: true)
        } else {
            cell.configure(title: "Nothing to create", icon: "xmark.circle", isAction: false)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .items:
            if indexPath.row == 0 {
                addItemTapped()
            }
        case .actions:
            createTapped()
        default:
            break
        }
    }
}

// MARK: - ViewModel Delegate

extension ReceiptReviewViewController: ReceiptReviewViewModelDelegate {
    func didUpdateSummary() {
        tableView.reloadSections(IndexSet(integer: 2), with: .none)
    }

    func didStartCreatingTransactions() {
        loadingOverlay.isHidden = false
        loadingIndicator.startAnimating()
    }

    func didCreateTransactions() {
        loadingOverlay.isHidden = true
        loadingIndicator.stopAnimating()
        let toast = ToastView(message: "Expenses created!")
        toast.show(in: view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    func didFailWithError(_ error: String) {
        loadingOverlay.isHidden = true
        loadingIndicator.stopAnimating()
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Custom Cells

fileprivate class EditableFieldCell: UITableViewCell {
    private let merchantLabel = UILabel()
    private let merchantTextField = UITextField()
    private let dateLabel = UILabel()
    private let datePickerField = UIDatePicker()
    private let warningStack = UIStackView()
    private let containerView = UIView()

    var onMerchantChange: ((String) -> Void)?
    var onDateChange: ((Date) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        containerView.layer.cornerRadius = AppTheme.CornerRadius.card
        AppTheme.Shadow.applyCard(to: containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        merchantLabel.text = "Merchant"
        merchantLabel.font = AppTheme.Fonts.captionMedium
        merchantLabel.textColor = AppTheme.Colors.textSecondary

        merchantTextField.placeholder = "Store name"
        merchantTextField.font = AppTheme.Fonts.body
        merchantTextField.textColor = AppTheme.Colors.textPrimary
        merchantTextField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        merchantTextField.layer.cornerRadius = AppTheme.CornerRadius.small
        merchantTextField.layer.borderWidth = 1
        merchantTextField.layer.borderColor = AppTheme.Colors.border.cgColor
        merchantTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        merchantTextField.leftViewMode = .always
        merchantTextField.addTarget(self, action: #selector(merchantTextChanged), for: .editingChanged)
        merchantTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        merchantTextField.translatesAutoresizingMaskIntoConstraints = false
        merchantTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        dateLabel.text = "Date"
        dateLabel.font = AppTheme.Fonts.captionMedium
        dateLabel.textColor = AppTheme.Colors.textSecondary

        datePickerField.datePickerMode = .date
        datePickerField.preferredDatePickerStyle = .compact
        datePickerField.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)

        warningStack.axis = .vertical
        warningStack.spacing = 6

        stack.addArrangedSubview(merchantLabel)
        stack.addArrangedSubview(merchantTextField)
        stack.addArrangedSubview(dateLabel)
        stack.addArrangedSubview(datePickerField)
        stack.addArrangedSubview(warningStack)

        containerView.addSubview(stack)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    func configure(merchant: String, date: Date?, warnings: [String]) {
        merchantTextField.text = merchant
        if let d = date {
            datePickerField.date = d
        }

        warningStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for warning in warnings {
            let label = UILabel()
            label.text = "⚠️ \(warning)"
            label.font = AppTheme.Fonts.caption
            label.textColor = AppTheme.Colors.warning
            label.numberOfLines = 0
            warningStack.addArrangedSubview(label)
        }
        warningStack.isHidden = warnings.isEmpty
    }

    @objc private func merchantTextChanged() {
        onMerchantChange?(merchantTextField.text ?? "")
    }

    @objc private func datePickerChanged() {
        onDateChange?(datePickerField.date)
    }
}

fileprivate class ReceiptItemCell: UITableViewCell {
    private let containerView = UIView()
    private let nameTextField = UITextField()
    private let priceTextField = UITextField()
    private let chipStack = UIStackView()
    private let deleteButton = UIButton(type: .system)

    private var mineButton: UIButton!
    private var sharedButton: UIButton!
    private var ignoreButton: UIButton!

    private var itemId: String?
    var onClassificationChange: ((ReceiptItemClassification) -> Void)?
    var onNameEdit: ((String) -> Void)?
    var onPriceEdit: ((Double) -> Void)?
    var onDelete: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        containerView.layer.cornerRadius = AppTheme.CornerRadius.medium
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        nameTextField.font = AppTheme.Fonts.body
        nameTextField.textColor = AppTheme.Colors.textPrimary
        nameTextField.placeholder = "Item name"
        nameTextField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        nameTextField.layer.cornerRadius = AppTheme.CornerRadius.small
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = AppTheme.Colors.border.cgColor
        nameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        nameTextField.leftViewMode = .always
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.heightAnchor.constraint(equalToConstant: 36).isActive = true

        priceTextField.font = AppTheme.Fonts.bodyMedium
        priceTextField.textColor = AppTheme.Colors.textPrimary
        priceTextField.textAlignment = .right
        priceTextField.placeholder = "0.00"
        priceTextField.keyboardType = .decimalPad
        priceTextField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        priceTextField.layer.cornerRadius = AppTheme.CornerRadius.small
        priceTextField.layer.borderWidth = 1
        priceTextField.layer.borderColor = AppTheme.Colors.border.cgColor
        priceTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        priceTextField.leftViewMode = .always
        priceTextField.addTarget(self, action: #selector(priceChanged), for: .editingChanged)
        priceTextField.translatesAutoresizingMaskIntoConstraints = false
        priceTextField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        priceTextField.heightAnchor.constraint(equalToConstant: 36).isActive = true

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = AppTheme.Colors.expense
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.widthAnchor.constraint(equalToConstant: 36).isActive = true

        topRow.addArrangedSubview(nameTextField)
        topRow.addArrangedSubview(priceTextField)
        topRow.addArrangedSubview(deleteButton)

        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.distribution = .fillEqually

        mineButton = makeChipButton(title: "Mine", color: AppTheme.Colors.income, action: #selector(mineTapped))
        sharedButton = makeChipButton(title: "Shared", color: AppTheme.Colors.accent, action: #selector(sharedTapped))
        ignoreButton = makeChipButton(title: "Ignore", color: AppTheme.Colors.textMuted, action: #selector(ignoreTapped))

        chipStack.addArrangedSubview(mineButton)
        chipStack.addArrangedSubview(sharedButton)
        chipStack.addArrangedSubview(ignoreButton)

        mainStack.addArrangedSubview(topRow)
        mainStack.addArrangedSubview(chipStack)

        containerView.addSubview(mainStack)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with item: ReceiptItem) {
        itemId = item.id
        nameTextField.text = item.name
        priceTextField.text = String(format: "%.2f", item.price)
        updateChipSelection(classification: item.classification)
    }

    private func makeChipButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = AppTheme.Fonts.buttonSmall
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 1
        b.layer.borderColor = AppTheme.Colors.border.cgColor
        b.addTarget(self, action: action, for: .touchUpInside)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return b
    }

    private func updateChipSelection(classification: ReceiptItemClassification) {
        let chips = [mineButton!, sharedButton!, ignoreButton!]
        let classifications: [ReceiptItemClassification] = [.mine, .shared, .ignore]

        for (idx, chip) in chips.enumerated() {
            let isSelected = classifications[idx] == classification
            let chipColor = chipColorForClassification(classifications[idx])
            if isSelected {
                chip.backgroundColor = chipColor
                chip.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
                chip.layer.borderColor = chipColor.cgColor
            } else {
                chip.backgroundColor = .clear
                chip.setTitleColor(AppTheme.Colors.textSecondary, for: .normal)
                chip.layer.borderColor = AppTheme.Colors.border.cgColor
            }
        }
    }

    private func chipColorForClassification(_ classification: ReceiptItemClassification) -> UIColor {
        switch classification {
        case .mine: return AppTheme.Colors.income
        case .shared: return AppTheme.Colors.accent
        case .ignore: return AppTheme.Colors.textMuted
        }
    }

    @objc private func mineTapped() { onClassificationChange?(.mine) }
    @objc private func sharedTapped() { onClassificationChange?(.shared) }
    @objc private func ignoreTapped() { onClassificationChange?(.ignore) }

    @objc private func nameChanged() {
        onNameEdit?(nameTextField.text ?? "")
    }

    @objc private func priceChanged() {
        let text = priceTextField.text?.replacingOccurrences(of: ",", with: "") ?? ""
        let price = Double(text) ?? 0
        onPriceEdit?(price)
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}

fileprivate class SummaryCell: UITableViewCell {
    private let containerView = UIView()
    private let personalLabel = UILabel()
    private let sharedLabel = UILabel()
    private let myShareLabel = UILabel()
    private let theyOweLabel = UILabel()
    private let totalLabel = UILabel()
    private let dividerView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        containerView.layer.cornerRadius = AppTheme.CornerRadius.card
        AppTheme.Shadow.applyCard(to: containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        personalLabel.font = AppTheme.Fonts.body
        personalLabel.textColor = AppTheme.Colors.textPrimary
        sharedLabel.font = AppTheme.Fonts.body
        sharedLabel.textColor = AppTheme.Colors.textPrimary
        myShareLabel.font = AppTheme.Fonts.body
        myShareLabel.textColor = AppTheme.Colors.expense
        theyOweLabel.font = AppTheme.Fonts.body
        theyOweLabel.textColor = AppTheme.Colors.accent
        totalLabel.font = AppTheme.Fonts.headingMedium
        totalLabel.textColor = AppTheme.Colors.textPrimary

        dividerView.backgroundColor = AppTheme.Colors.border
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Summary"
        titleLabel.font = AppTheme.Fonts.captionMedium
        titleLabel.textColor = AppTheme.Colors.textSecondary

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(personalLabel)
        stack.addArrangedSubview(sharedLabel)
        stack.addArrangedSubview(dividerView)
        stack.addArrangedSubview(myShareLabel)
        stack.addArrangedSubview(theyOweLabel)
        stack.addArrangedSubview(totalLabel)

        containerView.addSubview(stack)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    func configure(personalTotal: Double, sharedTotal: Double, myShare: Double, theyOwe: Double, totalCounted: Double, formatter: NumberFormatter, hasTax: Bool, taxAmount: Double, includeTax: Bool) {
        personalLabel.text = "Personal items: \(formatter.string(from: NSNumber(value: personalTotal)) ?? "$0.00")"
        sharedLabel.text = "Shared items: \(formatter.string(from: NSNumber(value: sharedTotal)) ?? "$0.00")"
        myShareLabel.text = "My share: \(formatter.string(from: NSNumber(value: myShare)) ?? "$0.00")"
        theyOweLabel.text = "They owe: \(formatter.string(from: NSNumber(value: theyOwe)) ?? "$0.00")"
        totalLabel.text = "Total counted: \(formatter.string(from: NSNumber(value: totalCounted)) ?? "$0.00")"

        if hasTax && includeTax {
            personalLabel.text? += " (incl. tax)"
            sharedLabel.text? += " (incl. tax)"
        }

        personalLabel.isHidden = personalTotal == 0
        sharedLabel.isHidden = sharedTotal == 0
        dividerView.isHidden = sharedTotal == 0
    }
}

fileprivate class ToggleCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let toggleSwitch = UISwitch()

    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = AppTheme.Colors.cardBackground
        layer.cornerRadius = AppTheme.CornerRadius.medium
        contentView.backgroundColor = .clear

        titleLabel.font = AppTheme.Fonts.body
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        toggleSwitch.onTintColor = AppTheme.Colors.accent
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = title
        toggleSwitch.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func toggleChanged() {
        onToggle?(toggleSwitch.isOn)
    }
}

fileprivate class ActionCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = AppTheme.Colors.cardBackgroundAlt
        layer.cornerRadius = AppTheme.CornerRadius.medium
        contentView.backgroundColor = .clear

        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppTheme.Fonts.body
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    func configure(title: String, icon: String, isAction: Bool = false) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: icon)
        if isAction {
            iconView.tintColor = AppTheme.Colors.expense
            titleLabel.textColor = AppTheme.Colors.expense
            titleLabel.font = AppTheme.Fonts.bodyBold
        } else {
            iconView.tintColor = AppTheme.Colors.textMuted
            titleLabel.textColor = AppTheme.Colors.textPrimary
            titleLabel.font = AppTheme.Fonts.body
        }
    }
}
