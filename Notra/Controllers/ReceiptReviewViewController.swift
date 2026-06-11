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
        b.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return b
    }()

    private let categoryTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Category *"
        l.font = AppTheme.Fonts.captionMedium
        l.textColor = AppTheme.Colors.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let categorySelectorButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = AppTheme.Colors.cardBackground
        b.layer.cornerRadius = AppTheme.CornerRadius.medium
        b.layer.borderWidth = 1
        b.layer.borderColor = AppTheme.Colors.border.cgColor
        b.contentHorizontalAlignment = .fill
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let label = UILabel()
        label.tag = 1001
        label.font = AppTheme.Fonts.body
        label.textColor = AppTheme.Colors.textSecondary
        label.text = "Select Category"
        label.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tag = 1002
        chevron.tintColor = AppTheme.Colors.textMuted
        chevron.translatesAutoresizingMaskIntoConstraints = false

        b.addSubview(label)
        b.addSubview(chevron)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: b.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16)
        ])

        return b
    }()

    private let helperLabel: UILabel = {
        let l = UILabel()
        l.font = AppTheme.Fonts.caption
        l.textColor = AppTheme.Colors.warning
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bottomStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 8
        s.translatesAutoresizingMaskIntoConstraints = false
        s.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        s.isLayoutMarginsRelativeArrangement = true
        s.backgroundColor = AppTheme.Colors.background
        return s
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

    init(geminiResult: GeminiReceiptResult, token: String) {
        self.viewModel = ReceiptReviewViewModel(receiptResult: geminiResult, token: token)
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
        setupKeyboardDismiss()
    }

    private func setupKeyboardDismiss() {
        tableView.keyboardDismissMode = .interactive
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HeaderCell")
        tableView.register(ReceiptItemCell.self, forCellReuseIdentifier: "ReceiptItemCell")
        tableView.register(ReceiptSummaryCardCell.self, forCellReuseIdentifier: "ReceiptSummaryCardCell")
        tableView.register(SummaryCell.self, forCellReuseIdentifier: "SummaryCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.register(EditableFieldCell.self, forCellReuseIdentifier: "EditableFieldCell")
        tableView.register(ToggleCell.self, forCellReuseIdentifier: "ToggleCell")
        tableView.register(PeopleCell.self, forCellReuseIdentifier: "PeopleCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(bottomStack)
        view.addSubview(loadingOverlay)
        loadingOverlay.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Configure bottom stack content
        categorySelectorButton.addTarget(self, action: #selector(categorySelectorTapped), for: .touchUpInside)
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)

        bottomStack.addArrangedSubview(categoryTitleLabel)
        bottomStack.addArrangedSubview(categorySelectorButton)
        bottomStack.addArrangedSubview(helperLabel)
        bottomStack.addArrangedSubview(createButton)

        helperLabel.isHidden = true
        updateCreateButtonState()

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])

        let bottomBarHeight: CGFloat = 160
        tableView.contentInset.bottom = bottomBarHeight
        tableView.verticalScrollIndicatorInsets.bottom = bottomBarHeight
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func createTapped() {
        view.endEditing(true)

        if viewModel.isCategoryRequired {
            guard viewModel.isCategorySelected else {
                let alert = UIAlertController(
                    title: "Category Required",
                    message: "Please select a category before creating expenses.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        }

        guard viewModel.mineCount + viewModel.sharedCount > 0 else {
            let alert = UIAlertController(
                title: "No Items Selected",
                message: "Please mark items as Mine or Shared before creating expenses.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

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
        tableView.reloadSections(IndexSet(integer: Section.summary.rawValue), with: .none)
    }

    @objc private func categorySelectorTapped() {
        presentCategoryPicker()
    }

    private func updateCreateButtonState() {
        let label = categorySelectorButton.viewWithTag(1001) as? UILabel
        let hasOptions = viewModel.hasCategoryOptions
        let requiresCategory = viewModel.isCategoryRequired

        if viewModel.isLoadingCategories {
            label?.text = "Loading categories..."
            label?.textColor = AppTheme.Colors.textMuted
            createButton.isEnabled = false
            createButton.backgroundColor = AppTheme.Colors.expense.withAlphaComponent(0.4)
            helperLabel.isHidden = true
        } else if !hasOptions && requiresCategory {
            label?.text = "No categories found"
            label?.textColor = AppTheme.Colors.warning
            createButton.isEnabled = false
            createButton.backgroundColor = AppTheme.Colors.expense.withAlphaComponent(0.4)
            helperLabel.isHidden = false
            helperLabel.text = "Please set up categories first"
        } else if let name = viewModel.selectedCategoryName, viewModel.isCategorySelected {
            label?.text = name
            label?.textColor = AppTheme.Colors.textPrimary

            let enabled = viewModel.canCreateExpenses
            createButton.isEnabled = enabled
            createButton.backgroundColor = enabled ? AppTheme.Colors.expense : AppTheme.Colors.expense.withAlphaComponent(0.4)
            createButton.setTitle(viewModel.createButtonTitle, for: .normal)

            if enabled {
                helperLabel.isHidden = true
            } else {
                helperLabel.isHidden = false
                helperLabel.text = viewModel.helperText
            }
        } else if !requiresCategory {
            // Non-relation category: show suggestion or placeholder, button enabled based on items
            let suggested = viewModel.selectedCategoryName
            label?.text = suggested ?? "Category (optional)"
            label?.textColor = suggested != nil ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary

            let enabled = viewModel.canCreateExpenses
            createButton.isEnabled = enabled
            createButton.backgroundColor = enabled ? AppTheme.Colors.expense : AppTheme.Colors.expense.withAlphaComponent(0.4)
            createButton.setTitle(viewModel.createButtonTitle, for: .normal)
            if enabled {
                helperLabel.isHidden = true
            } else {
                helperLabel.isHidden = false
                helperLabel.text = viewModel.helperText
            }
        } else {
            label?.text = "Select Category"
            label?.textColor = AppTheme.Colors.textSecondary

            createButton.isEnabled = false
            createButton.backgroundColor = AppTheme.Colors.expense.withAlphaComponent(0.4)
            createButton.setTitle(viewModel.createButtonTitle, for: .normal)

            helperLabel.isHidden = false
            helperLabel.text = viewModel.helperText
        }
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
            self?.updateCreateButtonState()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate

extension ReceiptReviewViewController: UITableViewDataSource, UITableViewDelegate {

    enum Section: Int, CaseIterable {
        case header
        case people
        case items
        case receiptSummary
        case categoryPicker
        case adjustments
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
        case .people: return 1
        case .items: return viewModel.items.isEmpty ? 2 : viewModel.items.count + 1
        case .receiptSummary: return viewModel.hasReceiptSummaryData ? 1 : 0
        case .categoryPicker: return 0
        case .adjustments: return viewModel.hasAdjustments ? viewModel.adjustments.count : 0
        case .summary: return 1
        case .categories: return viewModel.hasTax ? 2 : 1
        case .actions: return 0
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .header:
            return configureHeaderCell(tableView, at: indexPath)
        case .people:
            return configurePeopleCell(tableView, at: indexPath)
        case .items:
            if indexPath.row == 0 {
                return configureItemsHeaderCell(tableView, at: indexPath)
            }
            return configureItemCell(tableView, at: indexPath)
        case .receiptSummary:
            return configureReceiptSummaryCell(tableView, at: indexPath)
        case .categoryPicker, .actions:
            return UITableViewCell()
        case .adjustments:
            return configureAdjustmentCell(tableView, at: indexPath)
        case .summary:
            return configureSummaryCell(tableView, at: indexPath)
        case .categories:
            if viewModel.hasTax && indexPath.row == 0 {
                return configureTaxToggleCell(tableView, at: indexPath)
            }
            return configureActionsCell(tableView, at: indexPath)
        case .none:
            return UITableViewCell()
        }
    }

    private func configureHeaderCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EditableFieldCell", for: indexPath) as! EditableFieldCell
        cell.configure(
            merchant: viewModel.displayMerchant,
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

    private func configurePeopleCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PeopleCell", for: indexPath) as! PeopleCell
        let people = viewModel.splitPeople
        let maxWidth = tableView.bounds.width - 48
        cell.configure(
            people: people,
            maxWidth: maxWidth,
            onAdd: { [weak self] name in
                self?.viewModel.addPerson(name: name)
                tableView.reloadSections(IndexSet(integer: Section.people.rawValue), with: .none)
                self?.updateCreateButtonState()
            },
            onDelete: { [weak self] id in
                self?.viewModel.deletePerson(id: id)
                tableView.reloadData()
                self?.updateCreateButtonState()
            }
        )
        return cell
    }

    private func configureAdjustmentCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        let adj = viewModel.adjustments[indexPath.row]
        let amountStr = adj.amount.map { String(format: " $%.2f", $0) } ?? ""
        cell.configure(title: "\(adj.name)\(amountStr)", icon: "arrow.uturn.backward.circle")
        return cell
    }

    private func configureItemsHeaderCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        cell.configure(title: "Add Item Manually", icon: "plus.circle")
        return cell
    }

    private func configureReceiptSummaryCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiptSummaryCardCell", for: indexPath) as! ReceiptSummaryCardCell
        cell.configure(
            subtotal: viewModel.receiptSubtotal,
            tax: viewModel.receiptTax,
            delivery: viewModel.receiptDeliveryCharged,
            deliveryFee: viewModel.receiptDeliveryFee,
            tip: viewModel.receiptTip,
            total: viewModel.receiptTotal
        )
        return cell
    }

    private func configureItemCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let itemIndex = indexPath.row - 1
        let item = viewModel.items[itemIndex]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiptItemCell", for: indexPath) as! ReceiptItemCell
        cell.configureGemini(id: item.id, name: item.name, price: item.finalPrice, classification: item.classification)
        cell.configurePeople(
            available: viewModel.splitPeople,
            selectedIds: item.sharedWith,
            isVisible: item.classification == .shared
        )
        cell.onClassificationChange = { [weak self] classification in
            self?.viewModel.setClassification(for: item.id, classification: classification)
            if let self = self {
                let itemRow = IndexPath(row: indexPath.row, section: Section.items.rawValue)
                self.tableView.reconfigureRows(at: [itemRow])
                self.tableView.reloadSections(IndexSet(integer: Section.summary.rawValue), with: .none)
                self.updateCreateButtonState()
            }
        }
        cell.onSharedWithChange = { [weak self] personIds in
            self?.viewModel.setSharedWith(for: item.id, personIds: personIds)
            if let self = self {
                let itemRow = IndexPath(row: indexPath.row, section: Section.items.rawValue)
                self.tableView.reconfigureRows(at: [itemRow])
                self.updateCreateButtonState()
            }
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
            self?.updateCreateButtonState()
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
            includeTax: viewModel.includeTaxProportionally,
            personOwes: viewModel.personOwes
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
            tableView.reloadSections(IndexSet(integer: Section.summary.rawValue), with: .none)
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

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let rows = self.tableView(tableView, numberOfRowsInSection: section)
        return rows == 0 ? 0 : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let rows = self.tableView(tableView, numberOfRowsInSection: section)
        return rows == 0 ? 0 : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == Section.items.rawValue && indexPath.row == 0 {
            addItemTapped()
        }
    }

    private func presentCategoryPicker() {
        let options = viewModel.categoryOptions

        if viewModel.isLoadingCategories {
            let alert = UIAlertController(title: "Categories", message: "Loading category options...", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        guard !options.isEmpty else {
            let alert = UIAlertController(title: "No Categories", message: "Could not load categories. Please try again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(title: "Select Category", message: nil, preferredStyle: .actionSheet)
        for option in options {
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self] _ in
                self?.viewModel.selectCategory(id: option.id, name: option.title)
                self?.updateCreateButtonState()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = categorySelectorButton
            popover.sourceRect = categorySelectorButton.bounds
        }
        present(alert, animated: true)
    }
}

// MARK: - ViewModel Delegate

extension ReceiptReviewViewController: ReceiptReviewViewModelDelegate {
    func didUpdateSummary() {
        tableView.reloadSections(IndexSet(integer: Section.summary.rawValue), with: .none)
        updateCreateButtonState()
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

    func didLoadCategoryOptions() {
        updateCreateButtonState()
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

fileprivate class ReceiptItemCell: UITableViewCell, UITextViewDelegate {
    private let containerView = UIView()
    private let nameTextView = UITextView()
    private let priceTextField = UITextField()
    private let chipStack = UIStackView()
    private let deleteButton = UIButton(type: .system)

    private var mineButton: UIButton!
    private var sharedButton: UIButton!
    private var ignoreButton: UIButton!

    private let peopleLabel = UILabel()
    private let peopleChipStack = UIStackView()
    private let peopleContainer = UIStackView()
    private let inlineWarningLabel: UILabel = {
        let l = UILabel()
        l.text = "Select at least one person"
        l.font = AppTheme.Fonts.small
        l.textColor = AppTheme.Colors.warning
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var itemId: String?
    private var availablePeople: [SplitPerson] = []
    private var selectedPersonIds: [String] = []
    var onClassificationChange: ((ReceiptItemClassification) -> Void)?
    var onSharedWithChange: (([String]) -> Void)?
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

        // --- Name (multiline UITextView, auto-expanding) ---
        nameTextView.font = AppTheme.Fonts.body
        nameTextView.textColor = AppTheme.Colors.textPrimary
        nameTextView.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        nameTextView.layer.cornerRadius = AppTheme.CornerRadius.small
        nameTextView.layer.borderWidth = 1
        nameTextView.layer.borderColor = AppTheme.Colors.border.cgColor
        nameTextView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        nameTextView.isScrollEnabled = false
        nameTextView.textContainer.lineBreakMode = .byWordWrapping
        nameTextView.delegate = self
        nameTextView.translatesAutoresizingMaskIntoConstraints = false
        nameTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameTextView.setContentCompressionResistancePriority(.required, for: .vertical)
        nameTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

        // --- Bottom row: price + delete ---
        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

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
        priceTextField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        priceTextField.heightAnchor.constraint(equalToConstant: 36).isActive = true

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = AppTheme.Colors.expense
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let priceLabel = UILabel()
        priceLabel.text = "$"
        priceLabel.font = AppTheme.Fonts.bodyMedium
        priceLabel.textColor = AppTheme.Colors.textSecondary
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        bottomRow.addArrangedSubview(priceLabel)
        bottomRow.addArrangedSubview(priceTextField)
        bottomRow.addArrangedSubview(deleteButton)

        // --- Chips ---
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.distribution = .fillEqually

        mineButton = makeChipButton(title: "Mine", color: AppTheme.Colors.income, action: #selector(mineTapped))
        sharedButton = makeChipButton(title: "Shared", color: AppTheme.Colors.accent, action: #selector(sharedTapped))
        ignoreButton = makeChipButton(title: "Ignore", color: AppTheme.Colors.textMuted, action: #selector(ignoreTapped))

        chipStack.addArrangedSubview(mineButton)
        chipStack.addArrangedSubview(sharedButton)
        chipStack.addArrangedSubview(ignoreButton)

        // --- People section (shown when Shared is selected) ---
        peopleLabel.text = "Shared with:"
        peopleLabel.font = AppTheme.Fonts.captionMedium
        peopleLabel.textColor = AppTheme.Colors.textSecondary

        peopleChipStack.axis = .horizontal
        peopleChipStack.spacing = 8
        peopleChipStack.alignment = .center
        peopleChipStack.distribution = .fillProportionally

        peopleContainer.axis = .vertical
        peopleContainer.spacing = 6
        peopleContainer.addArrangedSubview(peopleLabel)
        peopleContainer.addArrangedSubview(peopleChipStack)
        peopleContainer.isHidden = true

        // --- Assemble main stack ---
        mainStack.addArrangedSubview(nameTextView)
        mainStack.addArrangedSubview(bottomRow)
        mainStack.addArrangedSubview(chipStack)
        mainStack.addArrangedSubview(inlineWarningLabel)
        mainStack.addArrangedSubview(peopleContainer)

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
        nameTextView.text = item.name
        priceTextField.text = String(format: "%.2f", item.price)
        updateChipSelection(classification: item.classification)
    }

    func configureGemini(id: String, name: String, price: Double, classification: ReceiptItemClassification) {
        itemId = id
        nameTextView.text = name
        priceTextField.text = String(format: "%.2f", price)
        updateChipSelection(classification: classification)
    }

    func configurePeople(available: [SplitPerson], selectedIds: [String], isVisible: Bool) {
        availablePeople = available
        selectedPersonIds = selectedIds
        peopleContainer.isHidden = !isVisible

        // Show inline warning for shared items with no selected people
        if isVisible && selectedIds.isEmpty && !available.isEmpty {
            inlineWarningLabel.isHidden = false
        } else {
            inlineWarningLabel.isHidden = true
        }

        peopleChipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard isVisible else { return }

        for person in available {
            let isSelected = selectedIds.contains(person.id)
            let chip = makePersonChip(name: person.name, isSelected: isSelected)
            chip.tag = 0
            chip.accessibilityIdentifier = person.id
            chip.addTarget(self, action: #selector(personChipTapped(_:)), for: .touchUpInside)
            peopleChipStack.addArrangedSubview(chip)
        }
    }

    private func makePersonChip(name: String, isSelected: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(name, for: .normal)
        b.titleLabel?.font = AppTheme.Fonts.buttonSmall
        b.layer.cornerRadius = 12
        b.layer.borderWidth = 1
        b.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        b.heightAnchor.constraint(equalToConstant: 26).isActive = true
        if isSelected {
            b.backgroundColor = AppTheme.Colors.accent
            b.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
            b.layer.borderColor = AppTheme.Colors.accent.cgColor
        } else {
            b.backgroundColor = AppTheme.Colors.cardBackgroundAlt
            b.setTitleColor(AppTheme.Colors.textSecondary, for: .normal)
            b.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        return b
    }

    @objc private func personChipTapped(_ sender: UIButton) {
        guard let pid = sender.accessibilityIdentifier else { return }
        var ids = selectedPersonIds
        if let idx = ids.firstIndex(of: pid) {
            ids.remove(at: idx)
        } else {
            ids.append(pid)
        }
        onSharedWithChange?(ids)
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

    func updateChipSelection(classification: ReceiptItemClassification) {
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

    @objc private func priceChanged() {
        let text = priceTextField.text?.replacingOccurrences(of: ",", with: "") ?? ""
        let price = Double(text) ?? 0
        onPriceEdit?(price)
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        onNameEdit?(textView.text ?? "")
    }
}

// MARK: - Receipt Summary Card (shows receipt breakdown: subtotal / tax / delivery / tip / total)

fileprivate class ReceiptSummaryCardCell: UITableViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let rowStack = UIStackView()

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

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 12
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Receipt Summary"
        titleLabel.font = AppTheme.Fonts.captionMedium
        titleLabel.textColor = AppTheme.Colors.textSecondary

        rowStack.axis = .vertical
        rowStack.spacing = 8

        outerStack.addArrangedSubview(titleLabel)
        outerStack.addArrangedSubview(rowStack)

        containerView.addSubview(outerStack)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            outerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            outerStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    func configure(subtotal: Double?, tax: Double?, delivery: Double?, deliveryFee: Double?, tip: Double?, total: Double?) {
        rowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        func fmt(_ v: Double) -> String { f.string(from: NSNumber(value: v)) ?? "$0.00" }

        if let s = subtotal { addRow(label: "Subtotal", value: fmt(s), isBold: false) }
        if let t = tax { addRow(label: "Tax", value: fmt(t), isBold: false) }

        if let fee = deliveryFee, fee > 0, let charged = delivery, charged == 0 {
            addRow(label: "Delivery", value: "\(fmt(charged)) (was \(fmt(fee)))", isBold: false)
        } else if let charged = delivery {
            addRow(label: "Delivery", value: fmt(charged), isBold: false)
        } else if let fee = deliveryFee {
            addRow(label: "Delivery", value: fmt(fee), isBold: false)
        }

        if let t = tip { addRow(label: "Tip", value: fmt(t), isBold: false) }

        if let tot = total {
            let divider = UIView()
            divider.backgroundColor = AppTheme.Colors.border
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
            rowStack.addArrangedSubview(divider)
            addRow(label: "Total", value: fmt(tot), isBold: true)
        }
    }

    private func addRow(label: String, value: String, isBold: Bool) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing

        let labelView = UILabel()
        labelView.text = label
        labelView.font = isBold ? AppTheme.Fonts.bodyBold : AppTheme.Fonts.body
        labelView.textColor = AppTheme.Colors.textPrimary

        let valueView = UILabel()
        valueView.text = value
        valueView.font = isBold ? AppTheme.Fonts.bodyBold : AppTheme.Fonts.body
        valueView.textColor = isBold ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary
        valueView.textAlignment = .right

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(valueView)
        rowStack.addArrangedSubview(row)
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
    private let personOwesStack = UIStackView()
    private var personOwesLabels: [UILabel] = []

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

        personOwesStack.axis = .vertical
        personOwesStack.spacing = 4

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
        stack.addArrangedSubview(personOwesStack)
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

    func configure(personalTotal: Double, sharedTotal: Double, myShare: Double, theyOwe: Double, totalCounted: Double, formatter: NumberFormatter, hasTax: Bool, taxAmount: Double, includeTax: Bool, personOwes: [(name: String, amount: Double)] = []) {
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

        personOwesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        personOwesLabels.removeAll()
        personOwesStack.isHidden = personOwes.isEmpty
        for (name, amount) in personOwes {
            let label = UILabel()
            label.text = "\(name) owes: \(formatter.string(from: NSNumber(value: amount)) ?? "$0.00")"
            label.font = AppTheme.Fonts.body
            label.textColor = AppTheme.Colors.income
            personOwesStack.addArrangedSubview(label)
            personOwesLabels.append(label)
        }
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

fileprivate class PeopleCell: UITableViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let chipsStack = UIStackView()
    private let addButton = UIButton(type: .system)

    var onAdd: ((String) -> Void)?
    var onDelete: ((String) -> Void)?

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

        titleLabel.text = "Split People"
        titleLabel.font = AppTheme.Fonts.captionMedium
        titleLabel.textColor = AppTheme.Colors.textSecondary

        chipsStack.axis = .vertical
        chipsStack.spacing = 8
        chipsStack.alignment = .leading

        addButton.setTitle("+ Add Person", for: .normal)
        addButton.titleLabel?.font = AppTheme.Fonts.bodyMedium
        addButton.setTitleColor(AppTheme.Colors.accent, for: .normal)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(chipsStack)
        stack.addArrangedSubview(addButton)

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

    func configure(people: [SplitPerson], maxWidth: CGFloat = 300, onAdd: @escaping (String) -> Void, onDelete: @escaping (String) -> Void) {
        self.onAdd = onAdd
        self.onDelete = onDelete

        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if people.isEmpty {
            chipsStack.isHidden = true
            return
        }

        // Lay out chips with wrapping
        var currentRow = UIStackView()
        currentRow.axis = .horizontal
        currentRow.spacing = 8
        currentRow.alignment = .center
        var rowWidth: CGFloat = 0

        for person in people {
            let chip = UIButton(type: .system)
            chip.setTitle(person.name, for: .normal)
            chip.titleLabel?.font = AppTheme.Fonts.buttonSmall
            chip.backgroundColor = AppTheme.Colors.cardBackgroundAlt
            chip.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
            chip.layer.cornerRadius = 12
            chip.layer.borderWidth = 1
            chip.layer.borderColor = AppTheme.Colors.border.cgColor
            chip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            chip.accessibilityIdentifier = person.id
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.heightAnchor.constraint(equalToConstant: 28).isActive = true

            let deleteAction = UIAction(title: "Delete") { [weak self] _ in
                self?.onDelete?(person.id)
            }
            let menu = UIMenu(title: person.name, children: [deleteAction])
            chip.menu = menu
            chip.showsMenuAsPrimaryAction = true

            let chipWidth = person.name.size(withAttributes: [.font: AppTheme.Fonts.buttonSmall]).width + 20 + 20
            if rowWidth + chipWidth + 8 > maxWidth && rowWidth > 0 {
                chipsStack.addArrangedSubview(currentRow)
                currentRow = UIStackView()
                currentRow.axis = .horizontal
                currentRow.spacing = 8
                currentRow.alignment = .center
                rowWidth = 0
            }
            currentRow.addArrangedSubview(chip)
            rowWidth += chipWidth + 8
        }

        if currentRow.arrangedSubviews.count > 0 {
            chipsStack.addArrangedSubview(currentRow)
        }

        chipsStack.isHidden = false
    }

    @objc private func addTapped() {
        let alert = UIAlertController(title: "Add Person", message: "Enter the person's name", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Name"
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
            self?.onAdd?(name)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        findViewController()?.present(alert, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
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
