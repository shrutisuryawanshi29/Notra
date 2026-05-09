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
        sc.selectedSegmentTintColor = .systemBlue
        sc.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .selected)
        sc.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 15, weight: .medium)
        ], for: .normal)
        return sc
    }()

    private let segmentedContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGroupedBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.keyboardDismissMode = .interactive
        tv.sectionHeaderTopPadding = 0
        return tv
    }()



    private let saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Save Transaction"
        config.image = UIImage(systemName: "checkmark.circle.fill")
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGroupedBackground
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
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var fieldViews: [String: Any] = [:]
    private var datePickers: [String: UIDatePicker] = [:]
    private var switchControls: [String: UISwitch] = [:]
    private var pickerButtons: [String: UIButton] = [:]

    init(prefillData: [String: String] = [:], initialRole: DatabaseRole = .expense) {
        self.prefillData = prefillData
        self.initialRole = initialRole
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        viewModel = AddTransactionViewModel(prefillData: prefillData, initialRole: initialRole)
        viewModel.delegate = self

        segmentedControl.selectedSegmentIndex = initialRole == .expense ? 0 : 1
        let tint: UIColor = initialRole == .expense ? .systemRed : .systemGreen
        segmentedControl.selectedSegmentTintColor = tint
        saveButton.configuration?.baseBackgroundColor = tint

        viewModel.generateFields()
    }

    private func setupUI() {
        title = "Add Transaction"
        view.backgroundColor = .systemGroupedBackground

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

            segmentedControl.topAnchor.constraint(equalTo: segmentedContainer.topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: segmentedContainer.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: segmentedContainer.trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: segmentedContainer.bottomAnchor),
            segmentedControl.widthAnchor.constraint(equalTo: segmentedContainer.widthAnchor, constant: -16),

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

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        loadingIndicator.startAnimating()
        loadingView.isHidden = false
    }

    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "tray"))
        icon.tintColor = .tertiaryLabel
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(icon)

        let label = UILabel()
        label.text = "No editable fields"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "This database has no writable properties."
        sublabel.font = .systemFont(ofSize: 14)
        sublabel.textColor = .tertiaryLabel
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

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func modeChanged() {
        let role: DatabaseRole = segmentedControl.selectedSegmentIndex == 0 ? .expense : .income
        let tint: UIColor = role == .expense ? .systemRed : .systemGreen
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
                    let value = Double(tf.text?.replacingOccurrences(of: ",", with: ".") ?? "")
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
        let alert = UIAlertController(
            title: "Transaction Added",
            message: "The transaction has been saved to Notion.\n\nRefresh the Dashboard to see your updated data.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableView

extension AddTransactionViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.fields.isEmpty ? 0 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.fields.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = viewModel.fields[indexPath.row]

        switch field.propertyType {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormFieldCell", for: indexPath) as! FormFieldCell
            cell.configure(with: field, role: viewModel.selectedRole)
            fieldViews[field.propertyName] = cell.textField
            return cell

        case .richText:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormTextViewCell", for: indexPath) as! FormTextViewCell
            cell.configure(with: field, role: viewModel.selectedRole)
            fieldViews[field.propertyName] = cell.textView
            return cell

        case .number, .url, .email, .phoneNumber:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormFieldCell", for: indexPath) as! FormFieldCell
            cell.configure(with: field, role: viewModel.selectedRole)
            fieldViews[field.propertyName] = cell.textField
            return cell

        case .select, .multiSelect:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormPickerCell", for: indexPath) as! FormPickerCell
            let options = field.options.map { $0.name }
            cell.configure(with: field, role: viewModel.selectedRole, options: options)
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
            }
            pickerButtons[field.propertyName] = cell.valueButton
            cell.onTap = { [weak self] in
                self?.handleRelationTap(for: field, button: cell.valueButton)
            }
            return cell

        case .date:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormDateCell", for: indexPath) as! FormDateCell
            cell.configure(with: field, role: viewModel.selectedRole)
            datePickers[field.propertyName] = cell.datePicker
            return cell

        case .checkbox:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormSwitchCell", for: indexPath) as! FormSwitchCell
            cell.configure(with: field, role: viewModel.selectedRole)
            switchControls[field.propertyName] = cell.switchControl
            return cell

        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FormPickerCell", for: indexPath) as! FormPickerCell
            let options = field.options.map { $0.name }
            cell.configure(with: field, role: viewModel.selectedRole, options: options)
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
                    self?.showPickerAlert(for: field, options: options, button: button)
                })
            }
        } else {
            for option in options {
                alert.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                    self?.viewModel.updateSelectValue(propertyName: field.propertyName, value: option)
                    button.setTitle(option, for: .normal)
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
    }

    func didFailToLoadRelationOptions(for propertyName: String, error: String) {
        print("[AddTransactionVC] Failed to load relation options for '\(propertyName)': \(error)")
        if let button = pickerButtons[propertyName] {
            button.setTitle("Unable to load options", for: .normal)
            button.setTitleColor(.systemRed.withAlphaComponent(0.6), for: .normal)
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
        saveButton.configuration?.title = "Save Transaction"
        updateSaveButtonColor()
        showSuccess()
    }

    func didFailToSave(error: String) {
        print("[AddTransactionVC] Save failed: \(error)")
        loadingIndicator.stopAnimating()
        saveButton.isEnabled = true
        saveButton.configuration?.showsActivityIndicator = false
        saveButton.configuration?.title = "Save Transaction"
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
        let tint: UIColor = viewModel.selectedRole == .expense ? .systemRed : .systemGreen
        saveButton.configuration?.baseBackgroundColor = tint
    }
}

// MARK: - FormFieldCell (text input)

private class FormFieldCell: UITableViewCell {
    let textField = UITextField()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        textField.font = .systemFont(ofSize: 17)
        textField.textColor = .label
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            textField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with field: DynamicFormField, role: DatabaseRole) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField

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

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        relationIcon.image = UIImage(systemName: "arrow.triangle.swap")
        relationIcon.tintColor = .tertiaryLabel
        relationIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(relationIcon)

        valueButton.contentHorizontalAlignment = .leading
        valueButton.titleLabel?.font = .systemFont(ofSize: 17)
        valueButton.setTitleColor(.label, for: .normal)
        valueButton.translatesAutoresizingMaskIntoConstraints = false
        valueButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        contentView.addSubview(valueButton)

        loadingLabel.font = .systemFont(ofSize: 15)
        loadingLabel.textColor = .tertiaryLabel
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingLabel)

        let arrow = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrow.tintColor = .tertiaryLabel
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
        valueButton.setTitleColor(.placeholderText, for: .normal)
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
        valueButton.setTitleColor(.placeholderText, for: .normal)
    }
}

// MARK: - FormDateCell

private class FormDateCell: UITableViewCell {
    let datePicker = UIDatePicker()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.translatesAutoresizingMaskIntoConstraints = false
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

    func configure(with field: DynamicFormField, role: DatabaseRole) {
        nameLabel.text = field.displayName
        badgeLabel.isHidden = !field.isMappedCoreField
        datePicker.date = Date()
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

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
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

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        badgeLabel.text = "Required"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        textView.font = .systemFont(ofSize: 17)
        textView.backgroundColor = .clear
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