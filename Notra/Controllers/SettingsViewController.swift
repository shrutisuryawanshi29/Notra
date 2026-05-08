//
//  SettingsViewController.swift
//  Notra
//

import UIKit

class SettingsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case notionConnection
        case databaseMapping
        case data
        case debug
        case dangerZone
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .notionConnection: return 2
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
        content.textProperties.font = .systemFont(ofSize: 16)
        content.secondaryTextProperties.font = .systemFont(ofSize: 13)
        content.secondaryTextProperties.color = .secondaryLabel

        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }

        switch sectionType {
        case .notionConnection:
            if indexPath.row == 0 {
                content.text = "Selected Page"
                content.secondaryText = UserDefaultsManager.shared.selectedPageTitle ?? "None"
            } else {
                content.text = "Page ID"
                content.secondaryText = UserDefaultsManager.shared.selectedPageId ?? "None"
                content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            }

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
                content.textProperties.color = .systemIndigo
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
                content.textProperties.color = .systemIndigo
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

        case .debug:
            if indexPath.row == 0 {
                content.text = "Print Mapping Summary"
                content.textProperties.color = .systemBlue
                cell.selectionStyle = .default
            } else {
                content.text = "Print Cache Summary"
                content.textProperties.color = .systemBlue
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
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

        default:
            break
        }
    }

    private func showDebugAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}