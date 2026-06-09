//
//  AddTransactionViewController.swift
//  Notra
//

import UIKit

final class AddTransactionViewController: UIViewController {

    private var viewModel: AddTransactionViewModel!
    private var prefillData: [String: String] = [:]
    private var initialRole: DatabaseRole = .expense

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Expense", "Income"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.backgroundColor = .clear
        sc.selectedSegmentTintColor = AppTheme.Colors.expense
        sc.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: AppTheme.Fonts.buttonMedium
        ], for: .selected)
        sc.setTitleTextAttributes([
            .foregroundColor: AppTheme.Colors.textPrimary,
            .font: AppTheme.Fonts.buttonMedium
        ], for: .normal)
        return sc
    }()

    private let segmentedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        view.layer.cornerRadius = AppTheme.CornerRadius.card
        AppTheme.Shadow.applyCard(to: view)
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.keyboardDismissMode = .interactive
        tv.sectionHeaderTopPadding = 0
        tv.backgroundColor = AppTheme.Colors.background
        return tv
    }()



    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        // set dynamically in viewDidLoad
        config.image = UIImage(systemName: "checkmark.circle.fill")
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = AppTheme.Colors.expense
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Fonts.buttonLarge
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.Fonts.captionMedium
        label.textColor = AppTheme.Colors.expense
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading form..."
        label.font = AppTheme.Fonts.caption
        label.textColor = AppTheme.Colors.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = AppTheme.Colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var fieldViews: [String: Any] = [:]
    private var datePickers: [String: UIDatePicker] = [:]
    private var switchControls: [String: UISwitch] = [:]
    private var pickerButtons: [String: UIButton] = [:]
    private var editingTransaction: NormalizedTransaction?
    var onEditComplete: ((_ updatedTransaction: NormalizedTransaction, _ oldMonthKey: String?) -> Void)?

    private let suggestionEngine = ExpenseCategorySuggestionEngine()
    private var showSuggestions = false
    private var currentSuggestions: [CategorySuggestion] = []
    private var suggestionTimer: Timer?
    private var hasUserEditedTitleForSuggestions = false

    init(prefillData: [String: String] = [:], initialRole: DatabaseRole = .expense, editingTransaction: NormalizedTransaction? = nil) {
        self.prefillData = prefillData
        self.initialRole = initialRole
        self.editingTransaction = editingTransaction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        viewModel = AddTransactionViewModel(prefillData: prefillData, initialRole: initialRole, editingTransaction: editingTransaction)
        viewModel.delegate = self

        segmentedControl.selectedSegmentIndex = initialRole == .expense ? 0 : 1
        let tint: UIColor = initialRole == .expense ? AppTheme.Colors.expense : AppTheme.Colors.income
        segmentedControl.selectedSegmentTintColor = tint
        saveButton.configuration?.baseBackgroundColor = tint

        viewModel.generateFields()
        saveButton.configuration?.title = editingTransaction != nil ? "Update Transaction" : "Save Transaction"
    }

    private func setupUI() {
        title = editingTransaction != nil ? "Edit \(editingTransaction!.databaseRole.displayName)" : "Add Transaction"
        view.backgroundColor = AppTheme.Colors.background
        AppTheme.styleNavigationBar(navigationController?.navigationBar ?? UINavigationBar())

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FormFieldCell.self, forCellReuseIdentifier: "FormFieldCell")
        tableView.register(FormPickerCell.self, forCellReuseIdentifier: "FormPickerCell")
        tableView.register(FormDateCell.self, forCellReuseIdentifier: "FormDateCell")
        tableView.register(FormSwitchCell.self, forCellReuseIdentifier: "FormSwitchCell")
        tableView.register(FormTextViewCell.self, forCellReuseIdentifier: "FormTextViewCell")
        tableView.register(SplitToggleCell.self, forCellReuseIdentifier: "SplitToggleCell")
        tableView.register(SplitDetailCell.self, forCellReuseIdentifier: "SplitDetailCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = AppTheme.Colors.background

        view.addSubview(segmentedContainer)
        segmentedContainer.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(errorLabel)
        view.addSubview(saveButton)
        view.addSubview(loadingView)
        loadingView.addSubview(loadingIndicator)
        loadingView.addSubview(loadingLabel)
        view.addSubview(emptyStateView)
        setupEmptyState()

        NSLayoutConstraint.activate([
            segmentedContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedContainer.heightAnchor.constraint(equalToConstant: 44),

            segmentedControl.topAnchor.constraint(equalTo: segmentedContainer.topAnchor, constant: 4),
            segmentedControl.leadingAnchor.constraint(equalTo: segmentedContainer.leadingAnchor, constant: 4),
            segmentedControl.trailingAnchor.constraint(equalTo: segmentedContainer.trailingAnchor, constant: -4),
            segmentedControl.bottomAnchor.constraint(equalTo: segmentedContainer.bottomAnchor, constant: -4),

            tableView.topAnchor.constraint(equalTo: segmentedContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: errorLabel.topAnchor, constant: -8),

            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            errorLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -4),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 56),

            loadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),

            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),

            emptyStateView.topAnchor.constraint(equalTo: segmentedContainer.bottomAnchor, constant: 8),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: saveButton.topAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        loadingIndicator.startAnimating()
        loadingView.isHidden = false
    }

    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "tray"))
        icon.tintColor = AppTheme.Colors.textMuted
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(icon)

        let label = UILabel()
        label.text = "No editable fields"
        label.font = AppTheme.Fonts.headingMedium
        label.textColor = AppTheme.Colors.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "This database has no writable properties."
        sublabel.font = AppTheme.Fonts.caption
        sublabel.textColor = AppTheme.Colors.textMuted
        sublabel.textAlignment = .center
        sublabel.numberOfLines = 0
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(sublabel)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -40),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -40),

            sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            sublabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 40),
            sublabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -40)
        ])
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        tableView.contentInset.bottom = keyboardFrame.height
        tableView.verticalScrollIndicatorInsets.bottom = keyboardFrame.height
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func modeChanged() {
        let role: DatabaseRole = segmentedControl.selectedSegmentIndex == 0 ? .expense : .income
        let tint: UIColor = role == .expense ? AppTheme.Colors.expense : AppTheme.Colors.income
        segmentedControl.selectedSegmentTintColor = tint
        saveButton.configuration?.baseBackgroundColor = tint
        print("[AddTransactionVC] Mode changed to: \(role.displayName)")
        dismissKeyboard()
        pickerButtons.removeAll()
        fieldViews.removeAll()
        datePickers.removeAll()
        switchControls.removeAll()
        loadingView.isHidden = false
        loadingIndicator.startAnimating()
        loadingLabel.text = "Loading \(role.displayName) fields..."
        tableView.isHidden = true
        emptyStateView.isHidden = true
        errorLabel.isHidden = true
        viewModel.switchMode(to: role)
        suggestionTimer?.invalidate()
        showSuggestions = false
        currentSuggestions = []
        hasUserEditedTitleForSuggestions = false
    }

    @objc private func saveTapped() {
        dismissKeyboard()
        collectFieldValues()
        errorLabel.isHidden = true
        viewModel.saveTransaction()
    }

    private func collectFieldValues() {
        for (propertyName, view) in fieldViews {
            if let tf = view as? UITextField {
                let fieldType = fieldsByName[propertyName]?.propertyType
                if fieldType == .number {
                    let value = Double(tf.text?.replacingOccurrences(of: ",", with: "") ?? "")
                    viewModel.updateNumberValue(propertyName: propertyName, value: value)
                } else {
                    viewModel.updateStringValue(propertyName: propertyName, value: tf.text ?? "")
                }
            } else if let tv = view as? UITextView {
                viewModel.updateStringValue(propertyName: propertyName, value: tv.text)
            }
        }

        for (propertyName, picker) in datePickers {
            viewModel.updateDateValue(propertyName: propertyName, value: picker.date)
        }

        for (propertyName, switchControl) in switchControls {
            viewModel.updateBoolValue(propertyName: propertyName, value: switchControl.isOn)
        }
    }

    private var fieldsByName: [String: DynamicFormField] {
        Dictionary(uniqueKeysWithValues: viewModel.fields.map { ($0.propertyName, $0) })
    }

    private func updateUIForFields() {
        loadingView.isHidden = true
        loadingIndicator.stopAnimating()

        if viewModel.fields.isEmpty {
            tableView.isHidden = true
            emptyStateView.isHidden = false
        } else {
            tableView.isHidden = false
            emptyStateView.isHidden = true
            updateSaveButtonColor()
            tableView.reloadData()
        }
    }

    private func showSuccess() {
        if viewModel.isSplitExpense && viewModel.selectedRole == .expense {
            let metadataCol = viewModel.targetDatabaseMapping?.columnMapping?.expenseAppMetadataProperty
            if metadataCol == nil {
                let warning = ToastView(message: "Split details may not persist. Map a Split Details column in setup.")
                warning.show(in: view, duration: 2.0)
            }
        }

        if editingTransaction != nil {
            guard let tx = viewModel.editingTransaction else { return }
            let role = viewModel.selectedRole
            let message = role == .expense ? "Expense updated" : "Income updated"
            let toast = ToastView(message: message)
            let oldMonthKey = MonthMetadata(date: tx.date).monthKey
            let updatedTx = buildUpdatedTransaction(from: tx, updatedPage: viewModel.lastCreatedPage)
            toast.show(in: view, duration: 1.8) { [weak self] in
                self?.onEditComplete?(updatedTx, oldMonthKey)
                self?.dismiss(animated: true)
            }
        } else {
            let role = viewModel.selectedRole
            let message = role == .expense ? "Expense saved" : "Income saved"
            let toast = ToastView(message: message)

            if let page = viewModel.lastCreatedPage {
                let newTx = buildNewTransaction(from: page)
                if role == .expense {
                    SessionCacheManager.shared.addExpense(newTx)
                    if let entry = buildSuggestionEntryForSavedExpense() {
                        suggestionEngine.noteSavedExpense(title: newTx.title, entry: entry)
                    }
                } else {
                    SessionCacheManager.shared.addIncome(newTx)
                }
            }

            toast.show(in: view, duration: 1.8)
            resetFormAfterSuccessfulSave()
        }
    }

    private func resetFormAfterSuccessfulSave() {
        print("[AddTransactionVC] Resetting form after successful save")
        viewModel.resetForm()
        showSuggestions = false
        currentSuggestions = []
        hasUserEditedTitleForSuggestions = false
        tableView.reloadData()
        viewModel.autoSelectMonthClassification(for: Date())
        if let monthFieldName = viewModel.monthClassificationFieldName,
           let monthValue = viewModel.fieldValues[monthFieldName],
           let relationIds = monthValue.relationIds,
           let selectedId = relationIds.first,
           let options = viewModel.relationOptions[monthFieldName],
           let match = options.first(where: { $0.id == selectedId }),
           let button = pickerButtons[monthFieldName] {
            button.setTitle(match.title, for: .normal)
            button.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
        }
    }

    private func showError(_ message: String) {
        let title = editingTransaction != nil ? "Update Failed" : "Error"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Edit Mode Helpers

extension AddTransactionViewController {
    private func buildUpdatedTransaction(from original: NormalizedTransaction, updatedPage: NotionPage? = nil) -> NormalizedTransaction {
        let dateField = fieldsByName.values.first(where: { $0.propertyType == .date })
        let amountField = fieldsByName.values.first(where: { $0.propertyType == .number })
        let categoryField = fieldsByName.values.first(where: { $0.propertyType == .select || $0.propertyType == .relation || $0.propertyType == .multiSelect || $0.propertyType == .status })

        let newDate = dateField.flatMap { viewModel.fieldValues[$0.propertyName]?.dateValue } ?? original.date

        let newAmount: Double
        let paidAmount: Double?
        if viewModel.isSplitExpense && viewModel.selectedRole == .expense {
            newAmount = viewModel.myShareAmountForSplit
            let paid = viewModel.paidAmountForSplit
            paidAmount = paid > 0 ? paid : original.paidAmount
        } else {
            newAmount = amountField.flatMap { viewModel.fieldValues[$0.propertyName]?.numberValue } ?? original.amount
            paidAmount = original.paidAmount
        }

        let split: SplitMetadata?
        if viewModel.isSplitExpense, let p = paidAmount, p > 0 {
            split = SplitMetadata(
                enabled: true,
                paidAmount: p,
                myShare: abs(newAmount),
                theyOwe: viewModel.reimbursementAmountForSplit,
                type: viewModel.splitMethod.rawValue,
                status: viewModel.splitStatus,
                splitWith: nil
            )
        } else {
            split = nil
        }

        return NormalizedTransaction(
            id: original.id,
            title: titleFieldValue ?? original.title,
            amount: abs(newAmount),
            paidAmount: paidAmount,
            category: categoryFieldValue ?? original.category,
            date: newDate,
            databaseId: original.databaseId,
            databaseRole: original.databaseRole,
            rawProperties: updatedPage?.properties ?? original.rawProperties,
            splitMetadata: split
        )
    }

    private func buildNewTransaction(from page: NotionPage) -> NormalizedTransaction {
        let dateField = fieldsByName.values.first(where: { $0.propertyType == .date })
        let amountField = fieldsByName.values.first(where: { $0.propertyType == .number })

        let newDate = dateField.flatMap { viewModel.fieldValues[$0.propertyName]?.dateValue } ?? Date()

        let newAmount: Double
        let paidAmount: Double?
        if viewModel.isSplitExpense && viewModel.selectedRole == .expense {
            newAmount = viewModel.myShareAmountForSplit
            let paid = viewModel.paidAmountForSplit
            paidAmount = paid > 0 ? paid : nil
        } else {
            newAmount = amountField.flatMap { viewModel.fieldValues[$0.propertyName]?.numberValue } ?? 0
            paidAmount = nil
        }

        let split: SplitMetadata?
        if viewModel.isSplitExpense, let p = paidAmount, p > 0 {
            split = SplitMetadata(
                enabled: true,
                paidAmount: p,
                myShare: abs(newAmount),
                theyOwe: viewModel.reimbursementAmountForSplit,
                type: viewModel.splitMethod.rawValue,
                status: viewModel.splitStatus,
                splitWith: nil
            )
        } else {
            split = nil
        }

        return NormalizedTransaction(
            id: page.id,
            title: titleFieldValue ?? "\(viewModel.selectedRole.displayName) - \(page.id.prefix(8))",
            amount: abs(newAmount),
            paidAmount: paidAmount,
            category: categoryFieldValue,
            date: newDate,
            databaseId: viewModel.targetDatabaseId ?? page.parent.databaseId ?? "",
            databaseRole: viewModel.selectedRole,
            rawProperties: page.properties,
            splitMetadata: split
        )
    }

    private var titleFieldValue: String? {
        for field in viewModel.fields where field.propertyType == .title {
            if let val = viewModel.fieldValues[field.propertyName]?.stringValue, !val.isEmpty {
                return val
            }
        }
        return nil
    }

    private var categoryFormField: DynamicFormField? {
        viewModel.fields.first(where: { $0.mappedRole == "Category" })
    }

    private var categoryFieldIsEmpty: Bool {
        guard let f = categoryFormField else { return true }
        return viewModel.fieldValues[f.propertyName]?.isEmpty ?? true
    }

    private var categoryFieldValue: String? {
        for field in viewModel.fields {
            if field.propertyType == .select || field.propertyType == .status {
                if let val = viewModel.fieldValues[field.propertyName]?.selectValue { return val }
            }
            if field.propertyType == .multiSelect {
                if let vals = viewModel.fieldValues[field.propertyName]?.multiSelectValues, !vals.isEmpty {
                    return vals.joined(separator: ", ")
                }
            }
            if field.propertyType == .relation {
                if let ids = viewModel.fieldValues[field.propertyName]?.relationIds, let firstId = ids.first {
                    let opts = viewModel.relationOptions[field.propertyName] ?? []
                    if let match = opts.first(where: { $0.id == firstId }) {
                        return match.title
                    }
                }
            }
        }
        return nil
    }

    private func syncPaidAmountFromAmountField() {
        guard let amountField = viewModel.fields.first(where: { $0.propertyType == .number && $0.mappedRole == "Amount" }) else { return }
        let rawText = (fieldViews[amountField.propertyName] as? UITextField)?.text ?? ""
        let cleaned = rawText.replacingOccurrences(of: ",", with: "")
        let existingValue = Double(cleaned) ?? 0
        viewModel.setPaidAmountForSplit(existingValue)
        if viewModel.splitMethod == .half {
            viewModel.setMyShareForSplit(existingValue / 2)
        }
    }

    private func buildSuggestionEntryForSavedExpense() -> (displayName: String, value: SuggestedCategoryValue)? {
        guard let categoryField = categoryFormField else { return nil }
        let fv = viewModel.fieldValues[categoryField.propertyName]
        switch categoryField.propertyType {
        case .select:
            guard let name = fv?.selectValue else { return nil }
            return (name, .select(name: name))
        case .status:
            guard let name = fv?.selectValue else { return nil }
            return (name, .status(name: name))
        case .multiSelect:
            guard let names = fv?.multiSelectValues, let first = names.first else { return nil }
            return (first, .multiSelect(name: first))
        case .relation:
            guard let ids = fv?.relationIds, let firstId = ids.first else { return nil }
            let opts = viewModel.relationOptions[categoryField.propertyName] ?? []
            let title = opts.first(where: { $0.id == firstId })?.title ?? firstId
            return (title, .relation(id: firstId, title: title))
        default:
            return nil
        }
    }
}

// MARK: - UITableView

extension AddTransactionViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.fields.isEmpty ? 0 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let baseCount = viewModel.fields.count
        if viewModel.selectedRole == .expense {
            return baseCount + 2
        }
        return baseCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let fieldCount = viewModel.fields.count

        if viewModel.selectedRole == .expense {
            if indexPath.row == fieldCount {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SplitToggleCell", for: indexPath) as! SplitToggleCell
                cell.configure(isOn: viewModel.isSplitExpense)
                cell.onToggle = { [weak self] isOn in
                    self?.viewModel.setSplitEnabled(isOn)
                    if isOn {
                        self?.syncPaidAmountFromAmountField()
                    }
                    let detailsPath = IndexPath(row: fieldCount + 1, section: 0)
                    self?.tableView.reloadRows(at: [detailsPath], with: .none)
                    self?.tableView.performBatchUpdates(nil)
                }
                return cell
                } else if indexPath.row == fieldCount + 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SplitDetailCell", for: indexPath) as! SplitDetailCell
                if viewModel.isSplitExpense {
                    cell.configure(
                        method: viewModel.splitMethod,
                        paidAmount: viewModel.paidAmountForSplit,
                        myShare: viewModel.myShareAmountForSplit,
                        reimbursement: viewModel.reimbursementAmountForSplit
                    )
                    cell.isHidden = false
                    let detailPath = indexPath
                    cell.onMethodChange = { [weak self] method in
                        self?.viewModel.setSplitMethod(method)
                        if method == .half {
                            let paid = self?.viewModel.paidAmountForSplit ?? 0
                            self?.viewModel.setMyShareForSplit(paid / 2)
                        }
                        self?.tableView.reloadRows(at: [detailPath], with: .none)
                        self?.tableView.performBatchUpdates(nil)
                    }
                    cell.onMyShareChange = { [weak self, weak cell] share in
                        guard let self = self else { return }
                        self.viewModel.setMyShareForSplit(share)
                        if let cell = cell {
                            cell.updateDisplay(
                                paidAmount: self.viewModel.paidAmountForSplit,
                                reimbursement: self.viewModel.reimbursementAmountForSplit
                            )
                        }
                        self.tableView.performBatchUpdates(nil)
                    }
                } else {
                    cell.isHidden = true
                }
                return cell
            }
        }

        let field = viewModel.fields[indexPath.row]

        switch field.propertyType {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormFieldCell", for: indexPath) as! FormFieldCell
            cell.configure(with: field, role: viewModel.selectedRole)
            if let existingValue = viewModel.fieldValues[field.propertyName]?.stringValue {
                cell.textField.text = existingValue
            }
            cell.textField.addTarget(self, action: #selector(titleTextChanged), for: .editingChanged)
            cell.textField.addTarget(self, action: #selector(titleEditingEnded), for: .editingDidEnd)
            fieldViews[field.propertyName] = cell.textField
            return cell

        case .richText:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormTextViewCell", for: indexPath) as! FormTextViewCell
            cell.configure(with: field, role: viewModel.selectedRole)
            if let existingValue = viewModel.fieldValues[field.propertyName]?.stringValue {
                cell.textView.text = existingValue
            }
            fieldViews[field.propertyName] = cell.textView
            return cell

        case .number, .url, .email, .phoneNumber:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormFieldCell", for: indexPath) as! FormFieldCell
            cell.configure(with: field, role: viewModel.selectedRole)
            if let existingValue = viewModel.fieldValues[field.propertyName] {
                if field.propertyType == .number, let num = existingValue.numberValue {
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.minimumFractionDigits = 2
                    formatter.maximumFractionDigits = 2
                    cell.textField.text = formatter.string(from: NSNumber(value: num))
                } else if let str = existingValue.stringValue {
                    cell.textField.text = str
                }
            }
            if field.mappedRole == "Amount" {
                cell.textField.addTarget(self, action: #selector(amountTextChanged), for: .editingChanged)
            }
            fieldViews[field.propertyName] = cell.textField
            return cell

        case .select, .multiSelect:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormPickerCell", for: indexPath) as! FormPickerCell
            let options = field.options.map { $0.name }
            cell.configure(with: field, role: viewModel.selectedRole, options: options)
            if let existingValue = viewModel.fieldValues[field.propertyName] {
                if field.propertyType == .select, let val = existingValue.selectValue {
                    cell.valueButton.setTitle(val, for: .normal)
                    cell.valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
                } else if field.propertyType == .multiSelect, let vals = existingValue.multiSelectValues, !vals.isEmpty {
                    cell.valueButton.setTitle(vals.joined(separator: ", "), for: .normal)
                    cell.valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
                }
            }
            pickerButtons[field.propertyName] = cell.valueButton
            cell.onTap = { [weak self] in
                self?.showPickerAlert(for: field, options: options, button: cell.valueButton)
            }
            return cell

        case .relation:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormPickerCell", for: indexPath) as! FormPickerCell
            let relationOpts = viewModel.relationOptions[field.propertyName] ?? []
            if relationOpts.isEmpty {
                cell.configure(with: field, role: viewModel.selectedRole, placeholder: "Loading options...")
            } else {
                cell.configure(with: field, role: viewModel.selectedRole, relationOptions: relationOpts)
                if let existingValue = viewModel.fieldValues[field.propertyName],
                   let relationIds = existingValue.relationIds,
                   let selectedId = relationIds.first,
                   let match = relationOpts.first(where: { $0.id == selectedId }) {
                    cell.valueButton.setTitle(match.title, for: .normal)
                    cell.valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
                }
            }
            pickerButtons[field.propertyName] = cell.valueButton
            cell.onTap = { [weak self] in
                self?.handleRelationTap(for: field, button: cell.valueButton)
            }
            return cell

        case .date:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormDateCell", for: indexPath) as! FormDateCell
            let dateValue = viewModel.fieldValues[field.propertyName]?.dateValue
            cell.configure(with: field, role: viewModel.selectedRole, dateValue: dateValue)
            datePickers[field.propertyName] = cell.datePicker
            cell.onDateChanged = { [weak self] date in
                self?.viewModel.updateDateValue(propertyName: field.propertyName, value: date)
                self?.viewModel.autoSelectMonthClassification(for: date)
            }
            return cell

        case .checkbox:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormSwitchCell", for: indexPath) as! FormSwitchCell
            cell.configure(with: field, role: viewModel.selectedRole)
            if let existingValue = viewModel.fieldValues[field.propertyName], let val = existingValue.boolValue {
                cell.switchControl.isOn = val
            }
            switchControls[field.propertyName] = cell.switchControl
            return cell

        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormPickerCell", for: indexPath) as! FormPickerCell
            let options = field.options.map { $0.name }
            cell.configure(with: field, role: viewModel.selectedRole, options: options)
            if let existingValue = viewModel.fieldValues[field.propertyName], let val = existingValue.selectValue {
                cell.valueButton.setTitle(val, for: .normal)
                cell.valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
            }
            pickerButtons[field.propertyName] = cell.valueButton
            cell.onTap = { [weak self] in
                self?.showPickerAlert(for: field, options: options, button: cell.valueButton)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let requiredCount = viewModel.fields.filter { $0.isMappedCoreField }.count
        if requiredCount > 0 {
            return "Fields marked Required are used by Notra for core tracking."
        }
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = AppTheme.Colors.background
        let label = UILabel()
        label.font = AppTheme.Fonts.caption
        label.textColor = AppTheme.Colors.textMuted
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -8)
        ])
        let requiredCount = viewModel.fields.filter { $0.isMappedCoreField }.count
        label.text = requiredCount > 0 ? "Fields marked Required are used by Notra for core tracking." : nil
        label.isHidden = requiredCount == 0
        return footerView
    }
}

// MARK: - Category Suggestions

extension AddTransactionViewController {
    @objc private func titleTextChanged(_ sender: UITextField) {
        hasUserEditedTitleForSuggestions = true
        if let titleField = titleFormField {
            viewModel.updateStringValue(propertyName: titleField.propertyName, value: sender.text ?? "")
        }
        suggestionTimer?.invalidate()
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.computeSuggestions()
        }
    }

    @objc private func amountTextChanged(_ sender: UITextField) {
        guard let amountField = viewModel.fields.first(where: { $0.propertyType == .number && $0.mappedRole == "Amount" }) else { return }
        let value = Double(sender.text?.replacingOccurrences(of: ",", with: "") ?? "")
        viewModel.updateNumberValue(propertyName: amountField.propertyName, value: value)
        if viewModel.isSplitExpense {
            syncPaidAmountFromAmountField()
        }
    }

    @objc private func titleEditingEnded(_ sender: UITextField) {
        suggestionTimer?.invalidate()
        computeSuggestions()
    }

    private func computeSuggestions() {
        guard viewModel.selectedRole == .expense else {
            hideSuggestions()
            return
        }

        if viewModel.isEditMode && !hasUserEditedTitleForSuggestions {
            hideSuggestions()
            return
        }

        guard let titleText = titleFieldValue, titleText.count >= 3 else {
            hideSuggestions()
            return
        }

        guard let categoryField = categoryFormField else {
            hideSuggestions()
            return
        }

        switch categoryField.propertyType {
        case .select, .relation, .multiSelect, .status: break
        default:
            hideSuggestions()
            return
        }

        if !categoryFieldIsEmpty && !viewModel.isEditMode {
            hideSuggestions()
            return
        }

        suggestionEngine.rebuild(categoryPropertyName: categoryField.propertyName)
        let suggestions = suggestionEngine.suggestions(for: titleText)
        guard !suggestions.isEmpty else {
            hideSuggestions()
            return
        }

        currentSuggestions = Array(suggestions.prefix(3))
        showSuggestions = true
        updateTitleCellSuggestions()
    }

    private func hideSuggestions() {
        guard showSuggestions else { return }
        showSuggestions = false
        currentSuggestions = []
        updateTitleCellSuggestions()
    }

    private func applySuggestion(_ suggestion: CategorySuggestion) {
        guard let categoryField = categoryFormField else { return }

        switch suggestion.value {
        case .relation(let id, _):
            viewModel.updateRelationValue(propertyName: categoryField.propertyName, ids: [id])
        case .select(let name):
            viewModel.updateSelectValue(propertyName: categoryField.propertyName, value: name)
        case .status(let name):
            viewModel.updateSelectValue(propertyName: categoryField.propertyName, value: name)
        case .multiSelect(let name):
            viewModel.updateMultiSelectValue(propertyName: categoryField.propertyName, values: [name])
        }

        showSuggestions = false
        currentSuggestions = []
        updateTitleCellSuggestions()

        if let catIdx = viewModel.fields.firstIndex(where: { $0.propertyName == categoryField.propertyName }) {
            let catPath = IndexPath(row: catIdx, section: 0)
            if let cell = tableView.cellForRow(at: catPath) as? FormPickerCell {
                let display: String
                switch suggestion.value {
                case .relation(_, let title): display = title
                case .select(let name): display = name
                case .status(let name): display = name
                case .multiSelect(let name): display = name
                }
                cell.valueButton.setTitle(display, for: .normal)
                cell.valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
            }
        }
    }

    private var titleFieldIndex: Int? {
        viewModel.fields.firstIndex(where: { $0.mappedRole == "Title" })
    }

    private func updateTitleCellSuggestions() {
        guard let idx = titleFieldIndex else { return }
        let path = IndexPath(row: idx, section: 0)
        guard let cell = tableView.cellForRow(at: path) as? FormFieldCell else { return }
        cell.updateSuggestions(currentSuggestions) { [weak self] suggestion in
            self?.applySuggestion(suggestion)
        }
        tableView.performBatchUpdates(nil)
    }

    private var titleFormField: DynamicFormField? {
        viewModel.fields.first(where: { $0.mappedRole == "Title" })
    }
}

// MARK: - Picker Alerts

extension AddTransactionViewController {
    private func showPickerAlert(for field: DynamicFormField, options: [String], button: UIButton) {
        let alert = UIAlertController(title: "Select \(field.displayName)", message: nil, preferredStyle: .actionSheet)
        let isMulti = field.propertyType == .multiSelect

        if isMulti {
            var selected = Array(viewModel.fieldValues[field.propertyName]?.multiSelectValues ?? [])
            for option in options {
                let title = "\(selected.contains(option) ? "✓ " : "")\(option)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    if let i = selected.firstIndex(of: option) {
                        selected.remove(at: i)
                    } else {
                        selected.append(option)
                    }
                    self?.viewModel.updateMultiSelectValue(propertyName: field.propertyName, values: selected)
                    let display = selected.isEmpty ? "Select \(field.displayName)..." : selected.joined(separator: ", ")
                    button.setTitle(display, for: .normal)
                    if !selected.isEmpty { self?.hideSuggestions() }
                    self?.showPickerAlert(for: field, options: options, button: button)
                })
            }
        } else {
            for option in options {
                alert.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                    self?.viewModel.updateSelectValue(propertyName: field.propertyName, value: option)
                    button.setTitle(option, for: .normal)
                    self?.hideSuggestions()
                })
            }
        }

        alert.addAction(UIAlertAction(title: isMulti ? "Done" : "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }

        present(alert, animated: true)
    }

    private func handleRelationTap(for field: DynamicFormField, button: UIButton) {
        let relationOpts = viewModel.relationOptions[field.propertyName] ?? []
        if relationOpts.isEmpty {
            viewModel.loadRelationOptions(for: field)
        } else {
            showRelationPickerAlert(for: field, options: relationOpts, button: button)
        }
    }

    private func showRelationPickerAlert(for field: DynamicFormField, options: [(id: String, title: String)], button: UIButton) {
        let alert = UIAlertController(title: "Select \(field.displayName)", message: nil, preferredStyle: .actionSheet)

        for option in options {
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self] _ in
                self?.viewModel.updateRelationValue(propertyName: field.propertyName, ids: [option.id])
                button.setTitle(option.title, for: .normal)
                self?.hideSuggestions()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }

        present(alert, animated: true)
    }
}

// MARK: - ViewModel Delegate

extension AddTransactionViewController: AddTransactionViewModelDelegate {
    func didLoadFields(_ fields: [DynamicFormField]) {
        print("[AddTransactionVC] Loaded \(fields.count) fields for \(viewModel.selectedRole.displayName)")

        for field in fields {
            let requiredStatus = field.isRequired ? "required" : "optional"
            let mappedStatus = field.isMappedCoreField ? " [mapped: \(field.mappedRole ?? "")]" : ""
            print("[AddTransactionVC] Field: \(field.propertyName) (\(field.propertyType.rawValue)) - \(requiredStatus)\(mappedStatus)")
        }

        updateUIForFields()
        if let monthFieldName = viewModel.monthClassificationFieldName,
           viewModel.relationOptions[monthFieldName] != nil,
           let dateField = fields.first(where: { $0.propertyType == .date }),
           let dateValue = viewModel.fieldValues[dateField.propertyName]?.dateValue {
            viewModel.autoSelectMonthClassification(for: dateValue)
        }
    }

    func didFailToLoadFields(error: String) {
        print("[AddTransactionVC] Failed to load fields: \(error)")
        loadingView.isHidden = true
        loadingIndicator.stopAnimating()
        let label = emptyStateView.subviews.compactMap { $0 as? UILabel }.first { $0.font == .systemFont(ofSize: 18, weight: .medium) }
        label?.text = "Failed to load"
        let sublabel = emptyStateView.subviews.compactMap { $0 as? UILabel }.first { $0.font == .systemFont(ofSize: 14) }
        sublabel?.text = error
        emptyStateView.isHidden = false
        tableView.isHidden = true
    }

    func didLoadRelationOptions(for propertyName: String, options: [(id: String, title: String)]) {
        print("[AddTransactionVC] Loaded \(options.count) relation options for '\(propertyName)': \(options.map { $0.title }.joined(separator: ", "))")
        tableView.reloadData()
        if propertyName == viewModel.monthClassificationFieldName,
           let dateField = viewModel.fields.first(where: { $0.propertyType == .date }),
           let dateValue = viewModel.fieldValues[dateField.propertyName]?.dateValue {
            viewModel.autoSelectMonthClassification(for: dateValue)
        }
    }

    func didResetForm() {
        print("[AddTransactionVC] Form has been reset")
        updateSaveButtonColor()
        saveButton.isEnabled = true
        saveButton.configuration?.showsActivityIndicator = false
        saveButton.configuration?.title = editingTransaction != nil ? "Update Transaction" : "Save Transaction"
        errorLabel.isHidden = true
        loadingIndicator.stopAnimating()
    }

    func didAutoSelectMonthClassification(propertyName: String, title: String) {
        if let button = pickerButtons[propertyName] {
            button.setTitle(title, for: .normal)
            button.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
        }
    }

    func didFailToLoadRelationOptions(for propertyName: String, error: String) {
        print("[AddTransactionVC] Failed to load relation options for '\(propertyName)': \(error)")
        if let button = pickerButtons[propertyName] {
            button.setTitle("Unable to load options", for: .normal)
            button.setTitleColor(AppTheme.Colors.expense.withAlphaComponent(0.6), for: .normal)
        }
    }

    func didStartSaving() {
        print("[AddTransactionVC] Saving...")
        errorLabel.isHidden = true
        saveButton.isEnabled = false
        saveButton.configuration?.showsActivityIndicator = true
        saveButton.configuration?.title = "Saving..."
        loadingIndicator.startAnimating()
    }

    func didSaveSuccessfully() {
        print("[AddTransactionVC] Save successful")
        loadingIndicator.stopAnimating()
        saveButton.isEnabled = true
        saveButton.configuration?.showsActivityIndicator = false
        saveButton.configuration?.title = editingTransaction != nil ? "Update Transaction" : "Save Transaction"
        updateSaveButtonColor()
        showSuccess()
    }

    func didFailToSave(error: String) {
        print("[AddTransactionVC] Save failed: \(error)")
        loadingIndicator.stopAnimating()
        saveButton.isEnabled = true
        saveButton.configuration?.showsActivityIndicator = false
        saveButton.configuration?.title = editingTransaction != nil ? "Update Transaction" : "Save Transaction"
        updateSaveButtonColor()
        showError(error)
    }

    func didValidateForm(isValid: Bool, missingFields: [String]) {
        print("[AddTransactionVC] Validation: isValid=\(isValid), missing=\(missingFields)")
        if !isValid {
            let names = missingFields.joined(separator: ", ")
            errorLabel.text = "Please fill in: \(names)"
            errorLabel.isHidden = false
        }
    }

    private func updateSaveButtonColor() {
        let tint: UIColor = viewModel.selectedRole == .expense ? AppTheme.Colors.expense : AppTheme.Colors.income
        saveButton.configuration?.baseBackgroundColor = tint
    }
}

// MARK: - FormFieldCell (text input)

private class FormFieldCell: UITableViewCell {
    let textField = UITextField()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()
    private let contentStack = UIStackView()
    private let suggestionRowStack = UIStackView()
    private let suggestionLabel = UILabel()
    let suggestionChipStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.font = AppTheme.Fonts.captionBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = AppTheme.Colors.secondaryBrown
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        textField.font = AppTheme.Fonts.body
        textField.textColor = AppTheme.Colors.textPrimary
        textField.translatesAutoresizingMaskIntoConstraints = false

        suggestionLabel.text = "Suggestions"
        suggestionLabel.font = AppTheme.Fonts.small
        suggestionLabel.textColor = AppTheme.Colors.textMuted
        suggestionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        suggestionLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        suggestionChipStack.axis = .horizontal
        suggestionChipStack.spacing = 6
        suggestionChipStack.alignment = .center
        suggestionChipStack.translatesAutoresizingMaskIntoConstraints = false

        suggestionRowStack.axis = .horizontal
        suggestionRowStack.alignment = .center
        suggestionRowStack.spacing = 6
        suggestionRowStack.translatesAutoresizingMaskIntoConstraints = false
        suggestionRowStack.isHidden = true
        suggestionRowStack.addArrangedSubview(suggestionLabel)
        suggestionRowStack.addArrangedSubview(suggestionChipStack)
        suggestionRowStack.addArrangedSubview(UIView())

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(textField)
        contentStack.addArrangedSubview(suggestionRowStack)
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            contentStack.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }

    func configure(with field: DynamicFormField, role: DatabaseRole) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        textField.text = ""
        suggestionRowStack.isHidden = true

        switch field.propertyType {
        case .title:
            textField.placeholder = role == .income ? "Enter income title..." : "Enter expense title..."
            textField.keyboardType = .default
        case .number:
            textField.placeholder = "0.00"
            textField.keyboardType = .decimalPad
        case .url:
            textField.placeholder = "https://..."
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        case .email:
            textField.placeholder = "email@example.com"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        case .phoneNumber:
            textField.placeholder = "+1 (555) 000-0000"
            textField.keyboardType = .phonePad
        default:
            textField.placeholder = field.displayName
            textField.keyboardType = .default
        }
    }

    func updateSuggestions(_ suggestions: [CategorySuggestion], onTap: @escaping (CategorySuggestion) -> Void) {
        suggestionChipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for suggestion in suggestions {
            let chip = SuggestionChipView(title: suggestion.displayName)
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.onTap = { onTap(suggestion) }
            suggestionChipStack.addArrangedSubview(chip)
        }
        suggestionRowStack.isHidden = suggestions.isEmpty
    }
}

// MARK: - FormPickerCell (select/multi_select/relation)

private class FormPickerCell: UITableViewCell {
    let valueButton = UIButton(type: .system)
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()
    private let loadingLabel = UILabel()
    private let relationIcon = UIImageView()
    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.font = AppTheme.Fonts.captionBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = AppTheme.Colors.secondaryBrown
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        relationIcon.image = UIImage(systemName: "arrow.triangle.swap")
        relationIcon.tintColor = AppTheme.Colors.textMuted
        relationIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(relationIcon)

        valueButton.contentHorizontalAlignment = .leading
        valueButton.titleLabel?.font = AppTheme.Fonts.body
        valueButton.setTitleColor(AppTheme.Colors.textPrimary, for: .normal)
        valueButton.translatesAutoresizingMaskIntoConstraints = false
        valueButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        contentView.addSubview(valueButton)

        loadingLabel.font = AppTheme.Fonts.caption
        loadingLabel.textColor = AppTheme.Colors.textMuted
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingLabel)

        let arrow = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrow.tintColor = AppTheme.Colors.textMuted
        arrow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrow)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            relationIcon.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            relationIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            relationIcon.widthAnchor.constraint(equalToConstant: 16),
            relationIcon.heightAnchor.constraint(equalToConstant: 16),

            valueButton.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            valueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            valueButton.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -8),
            valueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            arrow.centerYAnchor.constraint(equalTo: valueButton.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            arrow.widthAnchor.constraint(equalToConstant: 10),
            arrow.heightAnchor.constraint(equalToConstant: 10),

            loadingLabel.centerYAnchor.constraint(equalTo: valueButton.centerYAnchor),
            loadingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20)
        ])
    }

    @objc private func buttonTapped() {
        onTap?()
    }

    func configure(with field: DynamicFormField, role: DatabaseRole, options: [String]) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        relationIcon.isHidden = true
        valueButton.isHidden = false
        loadingLabel.isHidden = true
        valueButton.setTitle("Select \(field.displayName)...", for: .normal)
        valueButton.setTitleColor(AppTheme.Colors.textMuted, for: .normal)
    }

    func configure(with field: DynamicFormField, role: DatabaseRole, placeholder: String) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        relationIcon.isHidden = false
        valueButton.isHidden = true
        loadingLabel.isHidden = false
        loadingLabel.text = placeholder
    }

    func configure(with field: DynamicFormField, role: DatabaseRole, relationOptions: [(id: String, title: String)]) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        relationIcon.isHidden = false
        valueButton.isHidden = false
        loadingLabel.isHidden = true
        valueButton.setTitle("Select \(field.displayName)...", for: .normal)
        valueButton.setTitleColor(AppTheme.Colors.textMuted, for: .normal)
    }
}

// MARK: - FormDateCell

private class FormDateCell: UITableViewCell {
    let datePicker = UIDatePicker()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()
    var onDateChanged: ((Date) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.font = AppTheme.Fonts.captionBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = AppTheme.Colors.secondaryBrown
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        contentView.addSubview(datePicker)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            datePicker.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            datePicker.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with field: DynamicFormField, role: DatabaseRole, dateValue: Date? = nil) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        datePicker.date = dateValue ?? Date()
    }

    @objc private func datePickerValueChanged() {
        onDateChanged?(datePicker.date)
    }
}

// MARK: - FormSwitchCell

private class FormSwitchCell: UITableViewCell {
    let switchControl = UISwitch()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.font = AppTheme.Fonts.captionBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = AppTheme.Colors.secondaryBrown
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        switchControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(switchControl)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            switchControl.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            switchControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            switchControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with field: DynamicFormField, role: DatabaseRole) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        switchControl.isOn = false
    }
}

// MARK: - FormTextViewCell (rich text multiline)

private class FormTextViewCell: UITableViewCell {
    let textView = UITextView()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.font = AppTheme.Fonts.captionBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = AppTheme.Colors.secondaryBrown
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        textView.font = AppTheme.Fonts.body
        textView.backgroundColor = .clear
        textView.textColor = AppTheme.Colors.textPrimary
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: -2, bottom: 4, right: -2)
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            textView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    func configure(with field: DynamicFormField, role: DatabaseRole) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        textView.text = ""
    }
}

// MARK: - Split Toggle Cell

private class SplitToggleCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let toggleSwitch = UISwitch()
    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        nameLabel.text = "Split Expense"
        nameLabel.font = AppTheme.Fonts.bodyBold
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        toggleSwitch.onTintColor = AppTheme.Colors.expense
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        contentView.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.topAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -14),
            contentView.bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14)
        ])
    }

    @objc private func toggleChanged() {
        onToggle?(toggleSwitch.isOn)
    }

    func configure(isOn: Bool) {
        toggleSwitch.isOn = isOn
    }
}

// MARK: - Split Detail Cell

private class SplitDetailCell: UITableViewCell, UITextFieldDelegate {
    private let methodSegments = UISegmentedControl(items: ["50/50", "Custom"])
    private let paidAmountLabel = UILabel()
    private let myShareField = UITextField()
    private let theyOweLabel = UILabel()
    private let helperLabel = UILabel()
    var onMethodChange: ((SplitMethod) -> Void)?
    var onMyShareChange: ((Double) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt

        let paidHeader = UILabel()
        paidHeader.text = "Amount paid"
        paidHeader.font = AppTheme.Fonts.captionBold
        paidHeader.textColor = AppTheme.Colors.textSecondary
        paidHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paidHeader)

        paidAmountLabel.font = AppTheme.Fonts.bodyBold
        paidAmountLabel.textColor = AppTheme.Colors.textPrimary
        paidAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paidAmountLabel)

        methodSegments.selectedSegmentIndex = 0
        methodSegments.translatesAutoresizingMaskIntoConstraints = false
        methodSegments.addTarget(self, action: #selector(methodChanged), for: .valueChanged)
        contentView.addSubview(methodSegments)

        let shareHeader = UILabel()
        shareHeader.text = "My share"
        shareHeader.font = AppTheme.Fonts.captionBold
        shareHeader.textColor = AppTheme.Colors.textSecondary
        shareHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shareHeader)

        myShareField.font = AppTheme.Fonts.body
        myShareField.textColor = AppTheme.Colors.textPrimary
        myShareField.placeholder = "0.00"
        myShareField.keyboardType = .decimalPad
        myShareField.borderStyle = .roundedRect
        myShareField.backgroundColor = AppTheme.Colors.background
        myShareField.translatesAutoresizingMaskIntoConstraints = false
        myShareField.delegate = self
        myShareField.addTarget(self, action: #selector(myShareChanged), for: .editingChanged)
        contentView.addSubview(myShareField)

        let oweHeader = UILabel()
        oweHeader.text = "They owe"
        oweHeader.font = AppTheme.Fonts.captionBold
        oweHeader.textColor = AppTheme.Colors.textSecondary
        oweHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(oweHeader)

        theyOweLabel.font = AppTheme.Fonts.body
        theyOweLabel.textColor = AppTheme.Colors.expense
        theyOweLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(theyOweLabel)

        helperLabel.text = "Your share is used for spending, budgets, and analytics."
        helperLabel.font = AppTheme.Fonts.small
        helperLabel.textColor = AppTheme.Colors.textMuted
        helperLabel.numberOfLines = 0
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(helperLabel)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        NSLayoutConstraint.activate([
            paidHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            paidHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            paidAmountLabel.topAnchor.constraint(equalTo: paidHeader.bottomAnchor, constant: 2),
            paidAmountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            paidAmountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            methodSegments.topAnchor.constraint(equalTo: paidAmountLabel.bottomAnchor, constant: 12),
            methodSegments.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            methodSegments.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            methodSegments.heightAnchor.constraint(equalToConstant: 32),

            shareHeader.topAnchor.constraint(equalTo: methodSegments.bottomAnchor, constant: 12),
            shareHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            myShareField.topAnchor.constraint(equalTo: shareHeader.bottomAnchor, constant: 4),
            myShareField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            myShareField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            myShareField.heightAnchor.constraint(equalToConstant: 40),

            oweHeader.topAnchor.constraint(equalTo: myShareField.bottomAnchor, constant: 12),
            oweHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            theyOweLabel.topAnchor.constraint(equalTo: oweHeader.bottomAnchor, constant: 2),
            theyOweLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            theyOweLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            helperLabel.topAnchor.constraint(equalTo: theyOweLabel.bottomAnchor, constant: 12),
            helperLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            helperLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            helperLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(method: SplitMethod, paidAmount: Double, myShare: Double, reimbursement: Double) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "USD"

        let numericFormatter = NumberFormatter()
        numericFormatter.numberStyle = .decimal
        numericFormatter.minimumFractionDigits = 2
        numericFormatter.maximumFractionDigits = 2

        paidAmountLabel.text = currencyFormatter.string(from: NSNumber(value: paidAmount)) ?? "$0"
        myShareField.text = numericFormatter.string(from: NSNumber(value: myShare)) ?? "0.00"
        theyOweLabel.text = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"

        switch method {
        case .half:
            methodSegments.selectedSegmentIndex = 0
            myShareField.isEnabled = false
            myShareField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        case .customAmount:
            methodSegments.selectedSegmentIndex = 1
            myShareField.isEnabled = true
            myShareField.backgroundColor = AppTheme.Colors.background
        }
    }

    func updateDisplay(paidAmount: Double, reimbursement: Double) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "USD"
        paidAmountLabel.text = currencyFormatter.string(from: NSNumber(value: paidAmount)) ?? "$0"
        theyOweLabel.text = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"
    }

    @objc private func methodChanged() {
        let method: SplitMethod = methodSegments.selectedSegmentIndex == 0 ? .half : .customAmount
        if method == .half {
            myShareField.isEnabled = false
            myShareField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        } else {
            myShareField.isEnabled = true
            myShareField.backgroundColor = AppTheme.Colors.background
        }
        onMethodChange?(method)
    }

    @objc private func myShareChanged() {
        let cleaned = myShareField.text?.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression) ?? ""
        let value = Double(cleaned) ?? 0
        onMyShareChange?(value)
    }
}