//
//  DatabaseRoleAssignmentViewController.swift
//  Notra
//

import UIKit

class DatabaseRoleAssignmentViewController: UIViewController {

    private let viewModel = DatabaseRoleAssignmentViewModel()

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let emptyLabel = UILabel()
    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Assign Database Roles"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RoleAssignmentCell.self, forCellReuseIdentifier: "RoleCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        view.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isHidden = true
        view.addSubview(statusLabel)

        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = "No databases found in this page.\n\nMake sure your Notion page contains databases."
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        continueButton.backgroundColor = .systemIndigo
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 12
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.isHidden = true
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -16),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            continueButton.widthAnchor.constraint(equalToConstant: 200),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupViewModel() {
        viewModel.delegate = self
        viewModel.loadDatabases()
    }

    @objc private func continueTapped() {
        viewModel.saveMappings()

        let expenseDBs = viewModel.getDatabasesWithRole(.expense)
        let incomeDBs = viewModel.getDatabasesWithRole(.income)

        if let firstExpense = expenseDBs.first {
            let columnVC = ColumnMappingViewController(database: firstExpense, role: .expense)
            navigationController?.pushViewController(columnVC, animated: true)
        } else if let firstIncome = incomeDBs.first {
            let columnVC = ColumnMappingViewController(database: firstIncome, role: .income)
            navigationController?.pushViewController(columnVC, animated: true)
        } else {
            let alert = UIAlertController(title: "No Role Assigned", message: "Please assign at least one database as Expense or Income.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

extension DatabaseRoleAssignmentViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.databases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RoleCell", for: indexPath) as! RoleAssignmentCell
        let db = viewModel.databases[indexPath.row]
        cell.configure(database: db, role: viewModel.getRole(for: indexPath.row)) { [weak self] role in
            self?.viewModel.assignRole(role, to: indexPath.row)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

extension DatabaseRoleAssignmentViewController: DatabaseRoleAssignmentViewModelDelegate {
    func roleAssignmentDidStartLoading() {
        activityIndicator.startAnimating()
        statusLabel.text = "Scanning for databases..."
        statusLabel.isHidden = false
        tableView.isHidden = true
        emptyLabel.isHidden = true
        continueButton.isHidden = true
    }

    func roleAssignmentDidFinishLoading(databases: [DiscoveredDatabase]) {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true

        if databases.isEmpty {
            tableView.isHidden = true
            emptyLabel.isHidden = false
            continueButton.isHidden = true
        } else {
            tableView.isHidden = false
            emptyLabel.isHidden = true
            continueButton.isHidden = false
            tableView.reloadData()
        }
    }

    func roleAssignmentDidFail(_ error: String) {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        tableView.isHidden = true
        emptyLabel.isHidden = false
        emptyLabel.text = "Couldn't scan databases.\n\nPlease go back and try again."
        continueButton.isHidden = true
    }
}

// MARK: - Custom Cell

class RoleAssignmentCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Expense", "Income", "Ignore"])
    private var onRoleChanged: ((DatabaseRole) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(database: DiscoveredDatabase, role: DatabaseRole, onChanged: @escaping (DatabaseRole) -> Void) {
        titleLabel.text = database.title
        onRoleChanged = onChanged

        switch role {
        case .expense: segmentedControl.selectedSegmentIndex = 0
        case .income: segmentedControl.selectedSegmentIndex = 1
        case .ignore: segmentedControl.selectedSegmentIndex = 2
        }
    }

    @objc private func segmentChanged() {
        let roles: [DatabaseRole] = [.expense, .income, .ignore]
        onRoleChanged?(roles[segmentedControl.selectedSegmentIndex])
    }
}