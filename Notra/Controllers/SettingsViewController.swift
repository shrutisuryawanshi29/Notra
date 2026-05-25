import UIKit

class SettingsViewController: UIViewController {

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = AppTheme.Colors.background
        return tv
    }()

    private enum ConnectionRow: Int, CaseIterable {
        case connectedPage
        case token
        case expenseDatabase
        case incomeDatabase
        case categoryRelation
        case monthClassification
        case monthlyBudget
        case lastSynced
        case expenseMapping
        case incomeMapping
        case reconnectNotion
        case rerunDatabaseDiscovery
    }

    private enum Section: Int, CaseIterable {
        case notionConnection
        case databaseMapping
        case data
        case debug
        case dangerZone
    }

    private let metadata = SetupMetadataService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Settings"
        view.backgroundColor = AppTheme.Colors.background

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorColor = AppTheme.Colors.border
        tableView.sectionHeaderTopPadding = 0
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        metadata.loadHealthData { [weak self] in
            self?.tableView.reloadData()
        }
    }

    private func resetSetup() {
        let alert = UIAlertController(
            title: "Reset Setup?",
            message: "This will clear your Notion connection and database mappings. You'll need to set up again from the beginning.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.performReset()
        })

        present(alert, animated: true)
    }

    private func performReset() {
        SetupStateManager.shared.resetSetup()

        if let windowScene = view.window?.windowScene,
           let window = windowScene.windows.first {
            let tokenEntryVC = TokenEntryViewController()
            let navController = UINavigationController(rootViewController: tokenEntryVC)
            window.rootViewController = navController
        }
    }

    private func refreshData() {
        if let nav = navigationController {
            nav.popToRootViewController(animated: false)
            if let dashboard = nav.viewControllers.first as? DashboardViewController {
                dashboard.viewModel.loadData()
            }
        }
    }

    private func navigateToSetupEntry() {
        guard let windowScene = view.window?.windowScene,
              let window = windowScene.windows.first else { return }
        let tokenEntryVC = TokenEntryViewController()
        let navController = UINavigationController(rootViewController: tokenEntryVC)
        window.rootViewController = navController
    }

    private func navigateToPagePicker() {
        guard let windowScene = view.window?.windowScene,
              let window = windowScene.windows.first else { return }
        let pagePickerVC = PagePickerViewController()
        let navController = UINavigationController(rootViewController: pagePickerVC)
        window.rootViewController = navController
    }

    private func showSectionHeader(in cell: UITableViewCell, title: String) {
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.textProperties.font = AppTheme.Fonts.captionBold
        content.textProperties.color = AppTheme.Colors.textSecondary
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .notionConnection: return ConnectionRow.allCases.count
        case .databaseMapping: return 3
        case .data: return 2
        case .debug: return 2
        case .dangerZone: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .notionConnection: return "Notion Connection"
        case .databaseMapping: return "Database Mapping"
        case .data: return "Data"
        case .debug: return "Debug"
        case .dangerZone: return "Danger Zone"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .none
        cell.selectionStyle = .none

        var content = cell.defaultContentConfiguration()
        content.textProperties.font = AppTheme.Fonts.body
        content.textProperties.color = AppTheme.Colors.textPrimary
        content.secondaryTextProperties.font = AppTheme.Fonts.caption
        content.secondaryTextProperties.color = AppTheme.Colors.textSecondary

        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }

        switch sectionType {
        case .notionConnection:
            configureNotionConnectionCell(cell: cell, content: &content, row: indexPath.row)

        case .databaseMapping:
            let mappings = ColumnMappingService.shared.loadDatabaseMappings()
            let expenseDBs = mappings.values.filter { $0.role == .expense }
            let incomeDBs = mappings.values.filter { $0.role == .income }

            if indexPath.row == 0 {
                content.text = "Expense Databases"
                content.secondaryText = expenseDBs.isEmpty ? "None" : "\(expenseDBs.count) configured"
            } else if indexPath.row == 1 {
                content.text = "Income Databases"
                content.secondaryText = incomeDBs.isEmpty ? "None" : "\(incomeDBs.count) configured"
            } else {
                content.text = "Edit Mapping"
                content.textProperties.color = AppTheme.Colors.accent
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

        case .data:
            if indexPath.row == 0 {
                content.text = "Last Loaded Month"
                if let month = SessionCacheManager.shared.lastLoadedMonth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMMM yyyy"
                    content.secondaryText = formatter.string(from: month)
                } else {
                    content.secondaryText = "Never"
                }
            } else {
                content.text = "Refresh Dashboard Data"
                content.textProperties.color = AppTheme.Colors.accent
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

        case .debug:
            if indexPath.row == 0 {
                content.text = "Print Mapping Summary"
                content.textProperties.color = AppTheme.Colors.accent
                cell.selectionStyle = .default
            } else {
                content.text = "Print Cache Summary"
                content.textProperties.color = AppTheme.Colors.accent
                cell.selectionStyle = .default
            }

        case .dangerZone:
            content.text = "Reset Setup"
            content.textProperties.color = .systemRed
            content.textProperties.alignment = .center
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = content
        return cell
    }

    private func configureNotionConnectionCell(cell: UITableViewCell, content: inout UIListContentConfiguration, row: Int) {
        guard let connectionRow = ConnectionRow(rawValue: row) else { return }

        switch connectionRow {
        case .connectedPage:
            content.text = "Connected Page"
            content.secondaryText = metadata.pageTitle ?? "None"
            content.secondaryTextProperties.color = metadata.pageTitle != nil ? AppTheme.Colors.textPrimary : AppTheme.Colors.textMuted

        case .token:
            content.text = "Token"
            content.secondaryText = metadata.tokenDisplay
            content.secondaryTextProperties.color = metadata.isTokenSaved ? AppTheme.Colors.income : AppTheme.Colors.expense

        case .expenseDatabase:
            if let db = metadata.expenseDatabase {
                content.text = db.databaseTitle
                content.secondaryText = "Expenses"
                content.secondaryTextProperties.color = AppTheme.Colors.income
            } else {
                content.text = "Expense Database"
                content.secondaryText = "Not configured"
                content.secondaryTextProperties.color = AppTheme.Colors.textMuted
            }

        case .incomeDatabase:
            if let db = metadata.incomeDatabase {
                content.text = db.databaseTitle
                content.secondaryText = "Income"
                content.secondaryTextProperties.color = AppTheme.Colors.income
            } else {
                content.text = "Income Database"
                content.secondaryText = "Not configured"
                content.secondaryTextProperties.color = AppTheme.Colors.textMuted
            }

        case .categoryRelation:
            content.text = "Category Relation"
            applyHealth(&content, health: metadata.categoryRelationHealth)

        case .monthClassification:
            content.text = "Month Classification"
            applyHealth(&content, health: metadata.monthClassificationHealth)

        case .monthlyBudget:
            content.text = "Monthly Budget"
            applyHealth(&content, health: metadata.budgetColumnHealth)

        case .lastSynced:
            content.text = "Last Synced"
            content.secondaryText = metadata.lastSyncDisplay
            content.secondaryTextProperties.color = metadata.lastSyncDate != nil ? AppTheme.Colors.textSecondary : AppTheme.Colors.textMuted

        case .expenseMapping:
            content.text = "Expense Mapping"
            content.secondaryText = metadata.expenseMappingSummary
            content.secondaryTextProperties.font = AppTheme.Fonts.small

        case .incomeMapping:
            content.text = "Income Mapping"
            content.secondaryText = metadata.incomeMappingSummary
            content.secondaryTextProperties.font = AppTheme.Fonts.small

        case .reconnectNotion:
            content.text = "Reconnect Notion"
            content.textProperties.color = AppTheme.Colors.accent
            cell.selectionStyle = .default

        case .rerunDatabaseDiscovery:
            content.text = "Re-run Database Discovery"
            content.textProperties.color = AppTheme.Colors.accent
            cell.selectionStyle = .default
        }
    }

    private func applyHealth(_ content: inout UIListContentConfiguration, health: SetupMetadataService.Health) {
        content.secondaryText = health.displayText
        switch health {
        case .good:
            content.secondaryTextProperties.color = AppTheme.Colors.income
        case .warning:
            content.secondaryTextProperties.color = AppTheme.Colors.warning
        case .error:
            content.secondaryTextProperties.color = AppTheme.Colors.expense
        case .unknown:
            content.secondaryTextProperties.color = AppTheme.Colors.textMuted
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .notionConnection:
            guard let connectionRow = ConnectionRow(rawValue: indexPath.row) else { return }
            switch connectionRow {
            case .reconnectNotion:
                navigateToSetupEntry()
            case .rerunDatabaseDiscovery:
                navigateToPagePicker()
            default:
                break
            }

        case .databaseMapping:
            if indexPath.row == 2 {
                navigationController?.popToRootViewController(animated: true)
            }

        case .data:
            if indexPath.row == 1 {
                refreshData()
            }

        case .debug:
            if indexPath.row == 0 {
                let summary = ColumnMappingService.shared.getSessionSummary()
                print(summary)
                showDebugAlert(title: "Mapping Summary", message: summary)
            } else {
                let summary = SessionCacheManager.shared.getTransactionSummary()
                print(summary)
                showDebugAlert(title: "Cache Summary", message: summary)
            }

        case .dangerZone:
            resetSetup()
        }
    }

    private func showDebugAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
