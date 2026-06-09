//
//  ColumnMappingViewController.swift
//  Notra
//

import UIKit

class ColumnMappingViewController: UIViewController {

    private let viewModel: ColumnMappingViewModel

    // Header section
    private let headerContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // Middle section - mapping card
    private let cardView = UIView()
    private let cardTitleLabel = UILabel()
    private let helpButton = UIButton(type: .system)

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        return tv
    }()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // Bottom section - save button
    private let saveButton = UIButton(type: .system)

    private var selectedCategoryColumn: String?
    private var categoryValues: [CategoryValue] = []

    init(database: DiscoveredDatabase, role: DatabaseRole) {
        self.viewModel = ColumnMappingViewModel(database: database, role: role)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.delegate = self
        viewModel.autoSuggestMapping()
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background
        title = "Map Columns"
        navigationController?.navigationBar.prefersLargeTitles = false
        AppTheme.styleNavigationBar(navigationController!.navigationBar)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        setupHeader()
        setupButton()
        setupCard()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Header Section (Top)
    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        let iconName = viewModel.role == .expense ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = viewModel.role == .expense ? AppTheme.Colors.expense : AppTheme.Colors.income
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(iconView)

        titleLabel.text = "Map \(viewModel.role.displayName) Columns"
        titleLabel.font = AppTheme.Fonts.headingLarge
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(titleLabel)

        subtitleLabel.text = "Connect your Notion columns to Notra fields"
        subtitleLabel.font = AppTheme.Fonts.body
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.setContentHuggingPriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(subtitleLabel)

        headerContainer.setContentHuggingPriority(.required, for: .vertical)
        headerContainer.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            // Header pinned to top - NO centerY
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Icon at top of header
            iconView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 16),
            iconView.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            // Title below icon
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -24),

            // Subtitle below title - end of header
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -24),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Card Section (Middle)
    private func setupCard() {
        AppTheme.applyCardStyle(to: cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        // Card fills middle space (lower hugging priority)
        cardView.setContentHuggingPriority(.defaultLow, for: .vertical)
        cardView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.addSubview(cardView)

        // Card header - compact, required hugging
        cardTitleLabel.text = "Column Mapping"
        cardTitleLabel.font = AppTheme.Fonts.captionBold
        cardTitleLabel.textColor = AppTheme.Colors.textPrimary
        cardTitleLabel.numberOfLines = 1
        cardTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardTitleLabel.setContentHuggingPriority(.required, for: .vertical)
        cardTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        cardView.addSubview(cardTitleLabel)

        // Help button - compact
        let helpConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        helpButton.setImage(UIImage(systemName: "questionmark.circle", withConfiguration: helpConfig), for: .normal)
        helpButton.tintColor = AppTheme.Colors.textMuted
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.setContentHuggingPriority(.required, for: .vertical)
        helpButton.setContentCompressionResistancePriority(.required, for: .vertical)
        helpButton.addTarget(self, action: #selector(showHelpTapped), for: .touchUpInside)
        cardView.addSubview(helpButton)

        // Table view - fills remaining space
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MappingCell.self, forCellReuseIdentifier: "MappingCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppTheme.Colors.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.backgroundColor = AppTheme.Colors.cardBackground
        tableView.isScrollEnabled = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
        cardView.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        cardView.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            // Card constrained between header and button
            cardView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            cardTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            helpButton.centerYAnchor.constraint(equalTo: cardTitleLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),

            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
    }

    // MARK: - Button Section (Bottom)
    private func setupButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Save & Continue"
        config.image = UIImage(systemName: "checkmark.circle.fill")
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = viewModel.role == .expense ? AppTheme.Colors.expense : AppTheme.Colors.income
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Fonts.buttonLarge
            return outgoing
        }

        saveButton.configuration = config
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            // Save button pinned to bottom
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 56),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func showHelpTapped() {
        let alert = UIAlertController(
            title: "Column Mapping",
            message: """
            Map your Notion columns to Notra fields:

            • **Title** - Transaction description
            • **Amount** - Money value (positive for income, negative for expense)
            • **Category** - Expense/income category
            • **Date** - Transaction date
            • **Split Details** - Optional Text column for split expense metadata

            Auto-suggestions are based on column names.
            Tap any row to change the mapping.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    @objc private func saveButtonTapped() {
        viewModel.saveAndParseCategories()
    }

    private func showColumnPicker(for field: ColumnField) {
        let properties: [String]
        if field == .appMetadata {
            properties = viewModel.propertyNames.filter { name in
                let type = viewModel.database.properties[name]?.type ?? ""
                return type == "rich_text" || type == "text"
            }
        } else {
            properties = viewModel.propertyNames
        }

        let picker = ColumnPickerViewController(
            title: field.placeholder,
            options: properties,
            emptyMessage: field == .appMetadata
                ? "No Text columns found.\n\nAdd a Text column named \"Split Details\" in your Expense database, then refresh this setup screen."
                : "No columns available."
        ) { [weak self] selected in
            self?.viewModel.setMapping(for: field, columnName: selected)
            self?.tableView.reloadData()
        }
        present(picker, animated: true)
    }

    private func showAppMetadataInfo() {
        let message = """
        Notra can track shared expenses. For example, if you pay $100 for groceries but your share is $50, Notra will count $50 toward your spending while remembering that you paid $100 total.

        To keep split details after the app restarts, add one optional Text column to your Expense database.

        Recommended:
        Column name: Split Details
        Type: Text

        Notra stores small metadata in this column. You can hide this column in your Notion view.

        Without this column, your expense amount can still save as your share, but split details like paid amount and owed amount may not persist after reopening the app.
        """
        let alert = UIAlertController(
            title: "Split Expense Details",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        alert.addAction(UIAlertAction(title: "Copy \"Split Details\"", style: .default) { _ in
            UIPasteboard.general.string = "Split Details"
        })
        present(alert, animated: true)
    }
}

extension ColumnMappingViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ColumnField.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MappingCell", for: indexPath) as! MappingCell
        let field = ColumnField.allCases[indexPath.row]
        let selectedColumn = viewModel.getMapping(for: field)
        cell.configure(field: field, selectedColumn: selectedColumn)
        if field == .appMetadata {
            cell.onInfoTap = { [weak self] in
                self?.showAppMetadataInfo()
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let field = ColumnField.allCases[indexPath.row]
        showColumnPicker(for: field)
    }
}

extension ColumnMappingViewController: ColumnMappingViewModelDelegate {
    func columnMappingDidStartLoading() {
        activityIndicator.startAnimating()
        tableView.isHidden = true
    }

    func columnMappingDidFinishLoading(mapping: ColumnMapping, categories: [CategoryValue]) {
        activityIndicator.stopAnimating()
        tableView.isHidden = false

        if !categories.isEmpty {
            print("Detected Categories:")
            for cat in categories {
                print("  - \(cat.name) (\(cat.sourceType))")
            }
        }

        navigateToNextDatabase()
    }

    func columnMappingDidFail(_ error: String) {
        activityIndicator.stopAnimating()
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func navigateToNextDatabase() {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        
        let pendingExpense = mappings.values.first { $0.role == .expense && $0.columnMapping == nil }
        let pendingIncome = mappings.values.first { $0.role == .income && $0.columnMapping == nil }

        if let pending = pendingExpense {
            showColumnMappingForDatabase(pending)
        } else if let pending = pendingIncome {
            showColumnMappingForDatabase(pending)
        } else {
            navigateToDashboard()
        }
    }

    private func showColumnMappingForDatabase(_ mappingData: DatabaseMappingData) {
        guard let token = UserDefaultsManager.shared.notionToken else {
            showError("No token")
            return
        }

        activityIndicator.startAnimating()
        
        let baseURL = AppConstants.API.notionBaseURL
        guard let url = URL(string: "\(baseURL)/databases/\(mappingData.databaseId)") else {
            showError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConstants.API.notionVersion, forHTTPHeaderField: "Notion-Version")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                if error != nil {
                    self?.showError("Failed to fetch database schema")
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let properties = json["properties"] as? [String: Any] else {
                    self?.showError("Failed to parse schema")
                    return
                }
                
                var dbProperties: [String: DiscoveredDatabase.DatabaseProperty] = [:]
                for (propName, propValue) in properties {
                    if let prop = propValue as? [String: Any], let propType = prop["type"] as? String {
                        var relationDataSourceId: String? = nil
                        if propType == "relation", let relationConfig = prop["relation"] as? [String: Any] {
                            relationDataSourceId = relationConfig["data_source_id"] as? String
                        }
                        dbProperties[propName] = DiscoveredDatabase.DatabaseProperty(name: propName, type: propType, relationDataSourceId: relationDataSourceId)
                    }
                }
                
                let db = DiscoveredDatabase(
                    id: mappingData.databaseId,
                    title: mappingData.databaseTitle,
                    parentPageId: "",
                    properties: dbProperties,
                    assignedRole: mappingData.role
                )
                
                let columnVC = ColumnMappingViewController(database: db, role: mappingData.role)
                self?.navigationController?.pushViewController(columnVC, animated: true)
            }
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func navigateToDashboard() {
        guard let token = UserDefaultsManager.shared.notionToken else { return }
        let dashboardVC = DashboardViewController(token: token)
        navigationController?.setViewControllers([dashboardVC], animated: true)
    }
}

// MARK: - Mapping Cell

class MappingCell: UITableViewCell {
    private let fieldIconView = UIImageView()
    private let fieldLabel = UILabel()
    private let valueLabel = UILabel()
    private let arrowImageView = UIImageView()
    private let infoButton = UIButton(type: .system)
    var onInfoTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AppTheme.Colors.cardBackground
        selectionStyle = .default
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = AppTheme.Colors.cardBackgroundAlt
            return view
        }()

        let fieldIconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        fieldIconView.preferredSymbolConfiguration = fieldIconConfig
        fieldIconView.tintColor = AppTheme.Colors.primaryBrown
        fieldIconView.contentMode = .scaleAspectFit
        fieldIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fieldIconView)

        fieldLabel.font = AppTheme.Fonts.bodyBold
        fieldLabel.textColor = AppTheme.Colors.textPrimary
        fieldLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fieldLabel)

        let infoConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        infoButton.setImage(UIImage(systemName: "info.circle", withConfiguration: infoConfig), for: .normal)
        infoButton.tintColor = AppTheme.Colors.textMuted
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.isHidden = true
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        contentView.addSubview(infoButton)

        valueLabel.font = AppTheme.Fonts.body
        valueLabel.textColor = AppTheme.Colors.textSecondary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = AppTheme.Colors.textMuted
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrowImageView)

        NSLayoutConstraint.activate([
            fieldIconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            fieldIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fieldIconView.widthAnchor.constraint(equalToConstant: 24),
            fieldIconView.heightAnchor.constraint(equalToConstant: 24),

            fieldLabel.leadingAnchor.constraint(equalTo: fieldIconView.trailingAnchor, constant: 12),
            fieldLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            infoButton.leadingAnchor.constraint(equalTo: fieldLabel.trailingAnchor, constant: 4),
            infoButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 22),
            infoButton.heightAnchor.constraint(equalToConstant: 22),

            valueLabel.leadingAnchor.constraint(equalTo: infoButton.trailingAnchor, constant: 8),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),

            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    @objc private func infoTapped() {
        onInfoTap?()
    }

    func configure(field: ColumnField, selectedColumn: String?) {
        fieldLabel.text = field.rawValue

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        infoButton.isHidden = true
        switch field {
        case .title:
            fieldIconView.image = UIImage(systemName: "text.alignleft", withConfiguration: iconConfig)
            fieldIconView.tintColor = AppTheme.Colors.primaryBrown
        case .amount:
            fieldIconView.image = UIImage(systemName: "dollarsign.circle", withConfiguration: iconConfig)
            fieldIconView.tintColor = AppTheme.Colors.expense
        case .category:
            fieldIconView.image = UIImage(systemName: "tag", withConfiguration: iconConfig)
            fieldIconView.tintColor = AppTheme.Colors.secondaryBrown
        case .date:
            fieldIconView.image = UIImage(systemName: "calendar", withConfiguration: iconConfig)
            fieldIconView.tintColor = AppTheme.Colors.income
        case .appMetadata:
            fieldIconView.image = UIImage(systemName: "square.and.pencil", withConfiguration: iconConfig)
            fieldIconView.tintColor = AppTheme.Colors.textMuted
            infoButton.isHidden = false
        }

        valueLabel.text = selectedColumn ?? "Not selected"
        valueLabel.textColor = selectedColumn != nil ? AppTheme.Colors.textPrimary : AppTheme.Colors.textMuted
    }
}

// MARK: - Column Picker

class ColumnPickerViewController: UIViewController {

    private let pickerTitle: String
    private let options: [String]
    private let emptyMessage: String
    private let onSelect: (String) -> Void

    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, options: [String], emptyMessage: String, onSelect: @escaping (String) -> Void) {
        self.pickerTitle = title
        self.options = options
        self.emptyMessage = emptyMessage
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppTheme.Colors.cardBackground
        appearance.titleTextAttributes = [.foregroundColor: AppTheme.Colors.textPrimary, .font: AppTheme.Fonts.bodyBold]
        appearance.shadowColor = .clear
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance

        let navItem = UINavigationItem(title: pickerTitle)
        navItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissTapped))
        navItem.rightBarButtonItem?.tintColor = AppTheme.Colors.primaryBrown
        navBar.setItems([navItem], animated: false)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorColor = AppTheme.Colors.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.tableFooterView = UIView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OptionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
    }

    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
}

extension ColumnPickerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(options.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if options.isEmpty {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = "No columns available"
            cell.textLabel?.textColor = AppTheme.Colors.textMuted
            cell.textLabel?.font = AppTheme.Fonts.body
            cell.detailTextLabel?.text = emptyMessage
            cell.detailTextLabel?.textColor = AppTheme.Colors.textSecondary
            cell.detailTextLabel?.font = AppTheme.Fonts.caption
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            cell.backgroundColor = AppTheme.Colors.background
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath)
        let name = options[indexPath.row]
        cell.textLabel?.text = name
        cell.textLabel?.textColor = AppTheme.Colors.textPrimary
        cell.textLabel?.font = AppTheme.Fonts.body
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = AppTheme.Colors.background
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < options.count else { return }
        dismiss(animated: true) { [weak self] in
            self?.onSelect(self?.options[indexPath.row] ?? "")
        }
    }
}
