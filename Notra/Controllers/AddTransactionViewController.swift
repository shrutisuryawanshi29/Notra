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
    private var scanCoordinator: ReceiptScanCoordinator?

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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "camera.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(scanReceiptTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.Colors.accent

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

    @objc private func scanReceiptTapped() {
        guard editingTransaction == nil else { return }
        let token = UserDefaultsManager.shared.notionToken ?? ""
        guard !token.isEmpty else { return }
        let coordinator = ReceiptScanCoordinator()
        self.scanCoordinator = coordinator
        coordinator.start(from: self, token: token) { [weak self] parseResult in
            guard let self = self, let result = parseResult else {
                self?.scanCoordinator = nil
                return
            }
            let vc = ReceiptReviewViewController(parseResult: result, token: token)
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
            self.scanCoordinator = nil
        }
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
                    let value = parseInputText(tf.text)
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
            let inputs = SplitInputs(
                myShare: viewModel.splitMethodType == .exactAmounts ? viewModel.splitMyShareExact : nil,
                myPercent: viewModel.splitMethodType == .percent ? viewModel.splitMyPercent : nil,
                theirPercent: viewModel.splitMethodType == .percent ? viewModel.splitTheirPercent : nil,
                adjustmentAmount: viewModel.splitMethodType == .adjustment ? viewModel.splitAdjustmentAmount : nil,
                adjustmentMode: viewModel.splitMethodType == .adjustment ? viewModel.splitAdjustmentMode : nil,
                entryMode: viewModel.splitEntryMode
            )
            split = SplitMetadata(
                enabled: true,
                paidAmount: p,
                myShare: abs(newAmount),
                theyOwe: viewModel.reimbursementAmountForSplit,
                type: viewModel.splitMethodType.rawValue,
                status: viewModel.splitStatus,
                splitWith: nil,
                inputs: inputs
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
            let inputs = SplitInputs(
                myShare: viewModel.splitMethodType == .exactAmounts ? viewModel.splitMyShareExact : nil,
                myPercent: viewModel.splitMethodType == .percent ? viewModel.splitMyPercent : nil,
                theirPercent: viewModel.splitMethodType == .percent ? viewModel.splitTheirPercent : nil,
                adjustmentAmount: viewModel.splitMethodType == .adjustment ? viewModel.splitAdjustmentAmount : nil,
                adjustmentMode: viewModel.splitMethodType == .adjustment ? viewModel.splitAdjustmentMode : nil,
                entryMode: viewModel.splitEntryMode
            )
            split = SplitMetadata(
                enabled: true,
                paidAmount: p,
                myShare: abs(newAmount),
                theyOwe: viewModel.reimbursementAmountForSplit,
                type: viewModel.splitMethodType.rawValue,
                status: viewModel.splitStatus,
                splitWith: nil,
                inputs: inputs
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

    private func parseInputText(_ text: String?) -> Double? {
        guard let t = text, !t.isEmpty else { return nil }
        let cleaned = t.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }

    private func syncPaidAmountFromAmountField() {
        guard let amountField = viewModel.fields.first(where: { $0.propertyType == .number && $0.mappedRole == "Amount" }) else { return }
        let rawText = (fieldViews[amountField.propertyName] as? UITextField)?.text ?? ""
        let existingValue = parseInputText(rawText) ?? 0
        viewModel.setPaidAmountForSplit(existingValue)
        if viewModel.splitMethodType == .splitEqually {
            viewModel.setMyShareForSplit(existingValue / 2)
        }
    }

    private func showSplitHelpSheet() {
        let sheetVC = SplitHelpViewController()
        sheetVC.modalPresentationStyle = .overFullScreen
        sheetVC.modalTransitionStyle = .crossDissolve
        present(sheetVC, animated: true)
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
                        type: viewModel.splitMethodType,
                        paidAmount: viewModel.paidAmountForSplit,
                        myShare: viewModel.myShareAmountForSplit,
                        reimbursement: viewModel.reimbursementAmountForSplit,
                        myPercent: viewModel.splitMyPercent,
                        theirPercent: viewModel.splitTheirPercent,
                        myShareExact: viewModel.splitMyShareExact,
                        theyOweExact: viewModel.splitTheyOweExact,
                        adjustmentAmount: viewModel.splitAdjustmentAmount,
                        adjustmentMode: viewModel.splitAdjustmentMode
                    )
                    cell.isHidden = false
                    cell.onMethodChange = { [weak self] type in
                        guard let self = self else { return }
                        self.viewModel.setSplitMethodType(type)
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onInfoTap = { [weak self] in
                        self?.showSplitHelpSheet()
                    }
                    cell.onMyShareChange = { [weak self, weak cell] share in
                        guard let self = self else { return }
                        self.viewModel.setSplitMyShareExact(share)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onTheyOweChange = { [weak self, weak cell] owe in
                        guard let self = self else { return }
                        self.viewModel.setSplitTheyOweExact(owe)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onMyPercentChange = { [weak self, weak cell] pct in
                        guard let self = self else { return }
                        self.viewModel.setSplitMyPercent(pct)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onTheirPercentChange = { [weak self, weak cell] pct in
                        guard let self = self else { return }
                        self.viewModel.setSplitTheirPercent(pct)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onAdjustmentChange = { [weak self, weak cell] amount in
                        guard let self = self else { return }
                        self.viewModel.setSplitAdjustmentAmount(amount)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
                        self.tableView.performBatchUpdates(nil)
                    }
                    cell.onAdjustmentModeChange = { [weak self, weak cell] mode in
                        guard let self = self else { return }
                        self.viewModel.setSplitAdjustmentMode(mode)
                        cell?.refreshDisplay(
                            myShare: self.viewModel.myShareAmountForSplit,
                            reimbursement: self.viewModel.reimbursementAmountForSplit
                        )
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
                    if num == floor(num) {
                        cell.textField.text = String(format: "%.0f", num)
                    } else {
                        cell.textField.text = String(format: "%.2f", num)
                    }
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
        let value = parseInputText(sender.text)
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
    private let paidHeader = UILabel()
    private let paidAmountLabel = UILabel()

    private let methodHeader = UILabel()
    private let infoButton = UIButton(type: .system)

    private let chipGrid = UIStackView()
    private var chipButtons: [UIButton] = []

    private let methodInputSection = UIStackView()
    private var currentInputViews: [UIView] = []

    private var iPayButton: UIButton?
    private var theyPayButton: UIButton?

    private var activeFieldTag: Int = 0
    private var exactMyField: UITextField?
    private var exactTheyField: UITextField?
    private var pctMyField: UITextField?
    private var pctTheirField: UITextField?
    private var adjAmountField: UITextField?
    private let inlineResultLabel = UILabel()

    private let summaryTileContainer = UIStackView()
    private let myShareTile = SummaryTileView(label: "Your share", accent: true)
    private let theyOweTile = SummaryTileView(label: "They owe", accent: false)

    private let helperLabel = UILabel()

    var onMethodChange: ((SplitMethodType) -> Void)?
    var onInfoTap: (() -> Void)?
    var onMyShareChange: ((Double) -> Void)?
    var onTheyOweChange: ((Double) -> Void)?
    var onMyPercentChange: ((Double) -> Void)?
    var onTheirPercentChange: ((Double) -> Void)?
    var onAdjustmentChange: ((Double) -> Void)?
    var onAdjustmentModeChange: ((String) -> Void)?

    private var selectedMethod: SplitMethodType = .splitEqually
    private var isUpdatingProgrammatically = false

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    private func formatPlainAmount(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func formatPlainPercent(_ value: Double) -> String {
        return String(format: "%.0f", value)
    }

    private func parseInputText(_ text: String?) -> Double? {
        guard let t = text, !t.isEmpty else { return nil }
        let cleaned = t.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        onMyShareChange = nil
        onTheyOweChange = nil
        onMyPercentChange = nil
        onTheirPercentChange = nil
        onAdjustmentChange = nil
        onAdjustmentModeChange = nil
        onMethodChange = nil
        onInfoTap = nil
        iPayButton = nil
        theyPayButton = nil
        isUpdatingProgrammatically = false
        exactMyField = nil
        exactTheyField = nil
        pctMyField = nil
        pctTheirField = nil
        adjAmountField = nil
        activeFieldTag = 0
    }

    // MARK: - Helpers

    private func makeChip(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = AppTheme.Fonts.bodyMedium
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        btn.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeTextField(placeholder: String, keyboardType: UIKeyboardType = .decimalPad) -> UITextField {
        let tf = UITextField()
        tf.font = AppTheme.Fonts.body
        tf.textColor = AppTheme.Colors.textPrimary
        tf.placeholder = placeholder
        tf.keyboardType = keyboardType
        tf.borderStyle = .roundedRect
        tf.backgroundColor = AppTheme.Colors.background
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.delegate = self
        return tf
    }

    private func updateChipSelection() {
        for chip in chipButtons {
            guard let title = chip.title(for: .normal) else { continue }
            let type = SplitMethodType.uiCases.first { $0.chipLabel == title }
            let isSelected = type == selectedMethod
            if isSelected {
                chip.backgroundColor = AppTheme.Colors.expense
                chip.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
                chip.layer.borderColor = AppTheme.Colors.expense.cgColor
                chip.titleLabel?.font = AppTheme.Fonts.bodyMedium
            } else {
                chip.backgroundColor = AppTheme.Colors.cardBackgroundAlt
                chip.setTitleColor(AppTheme.Colors.textMuted, for: .normal)
                chip.layer.borderColor = AppTheme.Colors.border.cgColor
                chip.titleLabel?.font = AppTheme.Fonts.bodyMedium
            }
        }
    }

    // MARK: - Setup

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        let pad: CGFloat = 20

        // Paid amount header
        paidHeader.text = "Amount paid"
        paidHeader.font = AppTheme.Fonts.captionBold
        paidHeader.textColor = AppTheme.Colors.textSecondary
        paidHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paidHeader)

        paidAmountLabel.font = AppTheme.Fonts.bodyBold
        paidAmountLabel.textColor = AppTheme.Colors.textPrimary
        paidAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paidAmountLabel)

        // Method header + info
        methodHeader.text = "Split method"
        methodHeader.font = AppTheme.Fonts.captionBold
        methodHeader.textColor = AppTheme.Colors.textSecondary
        methodHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(methodHeader)

        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = AppTheme.Colors.textMuted
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        contentView.addSubview(infoButton)

        // Chip grid (2x2)
        chipGrid.axis = .vertical
        chipGrid.spacing = 10
        chipGrid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chipGrid)

        let uiTypes = SplitMethodType.uiCases
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 10
        row1.distribution = .fillEqually
        for i in 0..<2 {
            let chip = makeChip(title: uiTypes[i].chipLabel)
            row1.addArrangedSubview(chip)
            chipButtons.append(chip)
        }
        chipGrid.addArrangedSubview(row1)

        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 10
        row2.distribution = .fillEqually
        for i in 2..<4 {
            let chip = makeChip(title: uiTypes[i].chipLabel)
            row2.addArrangedSubview(chip)
            chipButtons.append(chip)
        }
        chipGrid.addArrangedSubview(row2)

        // Method input section
        methodInputSection.axis = .vertical
        methodInputSection.spacing = 8
        methodInputSection.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(methodInputSection)

        // Bottom stack: summary tiles → inline result → helper (auto-collapses hidden)
        summaryTileContainer.axis = .horizontal
        summaryTileContainer.spacing = 12
        summaryTileContainer.distribution = .fillEqually
        summaryTileContainer.translatesAutoresizingMaskIntoConstraints = false
        summaryTileContainer.addArrangedSubview(myShareTile)
        summaryTileContainer.addArrangedSubview(theyOweTile)

        inlineResultLabel.font = AppTheme.Fonts.bodyMedium
        inlineResultLabel.textColor = AppTheme.Colors.textPrimary
        inlineResultLabel.textAlignment = .center
        inlineResultLabel.numberOfLines = 0
        inlineResultLabel.translatesAutoresizingMaskIntoConstraints = false

        helperLabel.font = AppTheme.Fonts.small
        helperLabel.textColor = AppTheme.Colors.textMuted
        helperLabel.numberOfLines = 0
        helperLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomStack = UIStackView(arrangedSubviews: [summaryTileContainer, inlineResultLabel, helperLabel])
        bottomStack.axis = .vertical
        bottomStack.spacing = 12
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            paidHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            paidHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),

            paidAmountLabel.topAnchor.constraint(equalTo: paidHeader.bottomAnchor, constant: 2),
            paidAmountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            paidAmountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            methodHeader.topAnchor.constraint(equalTo: paidAmountLabel.bottomAnchor, constant: 12),
            methodHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),

            infoButton.centerYAnchor.constraint(equalTo: methodHeader.centerYAnchor),
            infoButton.leadingAnchor.constraint(equalTo: methodHeader.trailingAnchor, constant: 6),
            infoButton.widthAnchor.constraint(equalToConstant: 18),
            infoButton.heightAnchor.constraint(equalToConstant: 18),

            chipGrid.topAnchor.constraint(equalTo: methodHeader.bottomAnchor, constant: 10),
            chipGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            chipGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            methodInputSection.topAnchor.constraint(equalTo: chipGrid.bottomAnchor, constant: 16),
            methodInputSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            methodInputSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            bottomStack.topAnchor.constraint(equalTo: methodInputSection.bottomAnchor, constant: 16),
            bottomStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            bottomStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            bottomStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Configure

    func configure(
        type: SplitMethodType,
        paidAmount: Double,
        myShare: Double,
        reimbursement: Double,
        myPercent: Double,
        theirPercent: Double,
        myShareExact: Double,
        theyOweExact: Double,
        adjustmentAmount: Double,
        adjustmentMode: String
    ) {
        selectedMethod = type

        paidAmountLabel.text = currencyFormatter.string(from: NSNumber(value: paidAmount)) ?? "$0"
        myShareTile.setValue(currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0")
        theyOweTile.setValue(currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0")

        updateChipSelection()
        rebuildInputs(for: type, myShareExact: myShareExact, theyOweExact: theyOweExact, myPercent: myPercent, theirPercent: theirPercent, adjustmentAmount: adjustmentAmount, adjustmentMode: adjustmentMode, myShare: myShare, reimbursement: reimbursement)
    }

    func refreshDisplay(myShare: Double, reimbursement: Double) {
        myShareTile.setValue(currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0")
        theyOweTile.setValue(currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0")
        isUpdatingProgrammatically = true
        if selectedMethod == .exactAmounts {
            if activeFieldTag != 101 { exactTheyField?.text = formatPlainAmount(reimbursement) }
            if activeFieldTag != 100 { exactMyField?.text = formatPlainAmount(myShare) }
        } else if selectedMethod == .percent {
            if activeFieldTag != 201 { pctTheirField?.text = formatPlainPercent(100 - (parsePercentFromField(pctMyField) ?? 50)) }
            if activeFieldTag != 200 { pctMyField?.text = formatPlainPercent(100 - (parsePercentFromField(pctTheirField) ?? 50)) }
            let shareDisplay = currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0"
            let oweDisplay = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"
            inlineResultLabel.text = "Your share \(shareDisplay)  ·  They owe \(oweDisplay)"
        } else if selectedMethod == .adjustment {
            let shareDisplay = currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0"
            let oweDisplay = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"
            inlineResultLabel.text = "Your share \(shareDisplay)  ·  They owe \(oweDisplay)"
        }
        isUpdatingProgrammatically = false
    }

    private func parsePaidAmount() -> Double {
        guard let text = paidAmountLabel.text else { return 0 }
        let cleaned = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned) ?? 0
    }

    private func parsePercentFromField(_ field: UITextField?) -> Double? {
        guard let t = field?.text, !t.isEmpty else { return nil }
        return Double(t)
    }

    // MARK: - Inputs

    private func rebuildInputs(for type: SplitMethodType, myShareExact: Double, theyOweExact: Double, myPercent: Double, theirPercent: Double, adjustmentAmount: Double, adjustmentMode: String, myShare: Double = 0, reimbursement: Double = 0) {
        currentInputViews.forEach { $0.removeFromSuperview() }
        currentInputViews.removeAll()
        exactMyField = nil
        exactTheyField = nil
        pctMyField = nil
        pctTheirField = nil
        adjAmountField = nil

        switch type {
        case .splitEqually:
            summaryTileContainer.isHidden = false
            inlineResultLabel.isHidden = true
            helperLabel.text = "Your share is used for spending, budgets, and analytics."

        case .exactAmounts:
            summaryTileContainer.isHidden = true
            inlineResultLabel.isHidden = true
            helperLabel.text = "Enter either side. The other updates automatically."

            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            methodInputSection.addArrangedSubview(row)
            currentInputViews.append(row)

            let myTf = makeTextField(placeholder: "0.00")
            myTf.tag = 100
            if myShareExact > 0 { myTf.text = formatPlainAmount(myShareExact) }
            myTf.addTarget(self, action: #selector(exactAmountChanged), for: .editingChanged)
            let myStack = labelAndInput(label: "My share", textField: myTf)
            row.addArrangedSubview(myStack)
            exactMyField = myTf

            let theirTf = makeTextField(placeholder: "0.00")
            theirTf.tag = 101
            if theyOweExact > 0 { theirTf.text = formatPlainAmount(theyOweExact) }
            theirTf.addTarget(self, action: #selector(theyOweExactChanged), for: .editingChanged)
            let theirStack = labelAndInput(label: "They owe", textField: theirTf)
            row.addArrangedSubview(theirStack)
            exactTheyField = theirTf

        case .percent:
            summaryTileContainer.isHidden = true
            inlineResultLabel.isHidden = false
            helperLabel.text = "Your share is used for spending, budgets, and analytics."

            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            methodInputSection.addArrangedSubview(row)
            currentInputViews.append(row)

            let myTf = makeTextField(placeholder: "50", keyboardType: .numberPad)
            myTf.tag = 200
            if myPercent > 0 { myTf.text = formatPlainPercent(myPercent) }
            myTf.addTarget(self, action: #selector(percentChanged), for: .editingChanged)
            let myStack = labelAndInput(label: "My %", textField: myTf)
            row.addArrangedSubview(myStack)
            pctMyField = myTf

            let theirTf = makeTextField(placeholder: "50", keyboardType: .numberPad)
            theirTf.tag = 201
            if theirPercent > 0 { theirTf.text = formatPlainPercent(theirPercent) }
            theirTf.addTarget(self, action: #selector(theirPercentChanged), for: .editingChanged)
            let theirStack = labelAndInput(label: "Their %", textField: theirTf)
            row.addArrangedSubview(theirStack)
            pctTheirField = theirTf

            let shareDisplay = currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0"
            let oweDisplay = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"
            inlineResultLabel.text = "Your share \(shareDisplay)  ·  They owe \(oweDisplay)"

        case .adjustment:
            summaryTileContainer.isHidden = true
            inlineResultLabel.isHidden = false
            helperLabel.text = "Your share is used for spending, budgets, and analytics."

            let label = UILabel()
            label.text = "Who pays extra?"
            label.font = AppTheme.Fonts.small
            label.textColor = AppTheme.Colors.textMuted
            methodInputSection.addArrangedSubview(label)
            currentInputViews.append(label)

            let container = UIView()
            container.backgroundColor = AppTheme.Colors.cardBackgroundAlt
            container.layer.cornerRadius = 8
            container.layer.borderWidth = 1
            container.layer.borderColor = AppTheme.Colors.border.cgColor
            container.translatesAutoresizingMaskIntoConstraints = false
            container.heightAnchor.constraint(equalToConstant: 36).isActive = true
            methodInputSection.addArrangedSubview(container)
            currentInputViews.append(container)

            let innerStack = UIStackView()
            innerStack.axis = .horizontal
            innerStack.spacing = 0
            innerStack.distribution = .fillEqually
            innerStack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(innerStack)
            NSLayoutConstraint.activate([
                innerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
                innerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                innerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                innerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
            ])

            let iPayBtn = UIButton(type: .system)
            iPayBtn.setTitle("I pay extra", for: .normal)
            iPayBtn.titleLabel?.font = AppTheme.Fonts.captionMedium
            iPayBtn.layer.cornerRadius = 6
            iPayBtn.translatesAutoresizingMaskIntoConstraints = false
            iPayBtn.addTarget(self, action: #selector(adjustmentModeExtraIPay), for: .touchUpInside)
            innerStack.addArrangedSubview(iPayBtn)
            self.iPayButton = iPayBtn

            let theyPayBtn = UIButton(type: .system)
            theyPayBtn.setTitle("They pay", for: .normal)
            theyPayBtn.titleLabel?.font = AppTheme.Fonts.captionMedium
            theyPayBtn.layer.cornerRadius = 6
            theyPayBtn.translatesAutoresizingMaskIntoConstraints = false
            theyPayBtn.addTarget(self, action: #selector(adjustmentModeExtraTheyPay), for: .touchUpInside)
            innerStack.addArrangedSubview(theyPayBtn)
            self.theyPayButton = theyPayBtn

            updateAdjustmentModeStyle(mode: adjustmentMode)

            let tf = makeTextField(placeholder: "0.00")
            tf.tag = 300
            if adjustmentAmount > 0 { tf.text = formatPlainAmount(adjustmentAmount) }
            tf.addTarget(self, action: #selector(adjustmentChanged), for: .editingChanged)
            let inputStack = labelAndInput(label: "Extra amount", textField: tf)
            methodInputSection.addArrangedSubview(inputStack)
            currentInputViews.append(inputStack)
            adjAmountField = tf

            let shareDisplay = currencyFormatter.string(from: NSNumber(value: myShare)) ?? "$0"
            let oweDisplay = currencyFormatter.string(from: NSNumber(value: reimbursement)) ?? "$0"
            inlineResultLabel.text = "Your share \(shareDisplay)  ·  They owe \(oweDisplay)"

        case .shares:
            summaryTileContainer.isHidden = false
            inlineResultLabel.isHidden = true
            helperLabel.text = "Your share is used for spending, budgets, and analytics."
        }
    }

    private func labelAndInput(label: String, textField: UITextField) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2

        let lbl = UILabel()
        lbl.text = label
        lbl.font = AppTheme.Fonts.small
        lbl.textColor = AppTheme.Colors.textMuted
        stack.addArrangedSubview(lbl)

        textField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(textField)

        return stack
    }

    // MARK: - Adjustment Mode Style

    private func updateAdjustmentModeStyle(mode: String) {
        let isIPay = mode != "extraTheyPay"
        iPayButton?.backgroundColor = isIPay ? AppTheme.Colors.expense : .clear
        iPayButton?.setTitleColor(isIPay ? AppTheme.Colors.buttonContent : AppTheme.Colors.textMuted, for: .normal)
        theyPayButton?.backgroundColor = isIPay ? .clear : AppTheme.Colors.expense
        theyPayButton?.setTitleColor(isIPay ? AppTheme.Colors.textMuted : AppTheme.Colors.buttonContent, for: .normal)
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeFieldTag = textField.tag
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal),
              let type = SplitMethodType.uiCases.first(where: { $0.chipLabel == title }) else { return }
        selectedMethod = type
        activeFieldTag = 0
        updateChipSelection()
        rebuildInputs(for: type, myShareExact: 0, theyOweExact: 0, myPercent: 50, theirPercent: 50, adjustmentAmount: 0, adjustmentMode: "extraIPay")
        if type == .adjustment { updateAdjustmentModeStyle(mode: "extraIPay") }
        onMethodChange?(type)
    }

    @objc private func infoTapped() {
        onInfoTap?()
    }

    @objc private func exactAmountChanged(_ sender: UITextField) {
        guard !isUpdatingProgrammatically, let value = parseInputText(sender.text) else { return }
        onMyShareChange?(value)
    }

    @objc private func theyOweExactChanged(_ sender: UITextField) {
        guard !isUpdatingProgrammatically, let value = parseInputText(sender.text) else { return }
        onTheyOweChange?(value)
    }

    @objc private func percentChanged(_ sender: UITextField) {
        guard !isUpdatingProgrammatically, let value = parseInputText(sender.text) else { return }
        onMyPercentChange?(value)
    }

    @objc private func theirPercentChanged(_ sender: UITextField) {
        guard !isUpdatingProgrammatically, let value = parseInputText(sender.text) else { return }
        onTheirPercentChange?(value)
    }

    @objc private func adjustmentChanged(_ sender: UITextField) {
        guard !isUpdatingProgrammatically, let value = parseInputText(sender.text) else { return }
        onAdjustmentChange?(value)
    }

    @objc private func adjustmentModeExtraIPay() {
        updateAdjustmentModeStyle(mode: "extraIPay")
        onAdjustmentModeChange?("extraIPay")
    }

    @objc private func adjustmentModeExtraTheyPay() {
        updateAdjustmentModeStyle(mode: "extraTheyPay")
        onAdjustmentModeChange?("extraTheyPay")
    }
}

// MARK: - Summary Tile

private class SummaryTileView: UIView {
    private let label = UILabel()
    private let valueLabel = UILabel()

    init(label text: String, accent: Bool) {
        super.init(frame: .zero)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = AppTheme.Colors.border.cgColor
        backgroundColor = AppTheme.Colors.background

        label.text = text
        label.font = AppTheme.Fonts.small
        label.textColor = AppTheme.Colors.textMuted
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        valueLabel.font = AppTheme.Fonts.headingMedium
        valueLabel.textColor = accent ? AppTheme.Colors.expense : AppTheme.Colors.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            valueLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    func setValue(_ val: String) {
        valueLabel.text = val
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Split Help Bottom Sheet

private class SplitHelpViewController: UIViewController {
    private let container = UIView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        container.backgroundColor = AppTheme.Colors.cardBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissTap))
        view.addGestureRecognizer(tap)

        titleLabel.text = "Split methods"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        for type in SplitMethodType.uiCases {
            let row = UIView()

            let name = UILabel()
            name.text = type.displayName
            name.font = AppTheme.Fonts.bodyBold
            name.textColor = AppTheme.Colors.textPrimary
            name.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(name)

            let desc = UILabel()
            desc.text = type.helpText
            desc.font = AppTheme.Fonts.small
            desc.textColor = AppTheme.Colors.textMuted
            desc.numberOfLines = 0
            desc.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(desc)

            NSLayoutConstraint.activate([
                name.topAnchor.constraint(equalTo: row.topAnchor),
                name.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                name.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                desc.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
                desc.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                desc.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                desc.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])

            stack.addArrangedSubview(row)
        }

        let gotItBtn = UIButton(type: .system)
        gotItBtn.setTitle("Got it", for: .normal)
        gotItBtn.titleLabel?.font = AppTheme.Fonts.bodyBold
        gotItBtn.backgroundColor = AppTheme.Colors.expense
        gotItBtn.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
        gotItBtn.layer.cornerRadius = 8
        gotItBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        gotItBtn.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        gotItBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gotItBtn)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            gotItBtn.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            gotItBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            gotItBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            gotItBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
    }

    @objc private func dismissTap(_ sender: UITapGestureRecognizer) {
        let loc = sender.location(in: view)
        if !container.frame.contains(loc) {
            dismiss(animated: true)
        }
    }

    @objc private func dismissSheet() {
        dismiss(animated: true)
    }
}