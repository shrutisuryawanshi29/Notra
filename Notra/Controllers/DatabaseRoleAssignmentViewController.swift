//
//  DatabaseRoleAssignmentViewController.swift
//  Notra
//

import UIKit

class DatabaseRoleAssignmentViewController: UIViewController {

    private let viewModel = DatabaseRoleAssignmentViewModel()

    // Header section
    private let headerContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // Middle section - database card
    private let cardView = UIView()
    private let cardTitleLabel = UILabel()
    private let helpButton = UIButton(type: .system)

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        return tv
    }()

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let emptyLabel = UILabel()

    // Bottom section - continue button
    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background
        title = "Assign Roles"
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

        iconView.image = UIImage(systemName: "folder.fill.badge.plus")
        iconView.tintColor = AppTheme.Colors.primaryBrown
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(iconView)

        titleLabel.text = "Assign Database Roles"
        titleLabel.font = AppTheme.Fonts.headingLarge
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(titleLabel)

        subtitleLabel.text = "Tell Notra how to categorize each database in your page"
        subtitleLabel.font = AppTheme.Fonts.body
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.setContentHuggingPriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        headerContainer.addSubview(subtitleLabel)

        // Set header container to hug content
        headerContainer.setContentHuggingPriority(.required, for: .vertical)
        headerContainer.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            // Header container pinned to top - NO centerY, pinned to top
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Icon at top of header container
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
        // Set card to FILL available space (lower hugging priority)
        cardView.setContentHuggingPriority(.defaultLow, for: .vertical)
        cardView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.addSubview(cardView)

        // Card header - compact, required hugging
        cardTitleLabel.text = "Databases Found"
        cardTitleLabel.font = AppTheme.Fonts.captionBold
        cardTitleLabel.textColor = AppTheme.Colors.textPrimary
        cardTitleLabel.numberOfLines = 1
        cardTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardTitleLabel.setContentHuggingPriority(.required, for: .vertical)
        cardTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        cardView.addSubview(cardTitleLabel)

        // Info button - compact, required hugging
        let helpConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        helpButton.setImage(UIImage(systemName: "questionmark.circle", withConfiguration: helpConfig), for: .normal)
        helpButton.tintColor = AppTheme.Colors.textMuted
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.setContentHuggingPriority(.required, for: .vertical)
        helpButton.setContentCompressionResistancePriority(.required, for: .vertical)
        helpButton.addTarget(self, action: #selector(showHelpTapped), for: .touchUpInside)
        cardView.addSubview(helpButton)

        // Table view - fills remaining space (lower hugging priority)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RoleAssignmentCell.self, forCellReuseIdentifier: "RoleCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppTheme.Colors.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.backgroundColor = AppTheme.Colors.cardBackground
        tableView.isScrollEnabled = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tableView.isHidden = true
        cardView.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        cardView.addSubview(activityIndicator)

        statusLabel.font = AppTheme.Fonts.body
        statusLabel.textColor = AppTheme.Colors.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isHidden = true
        cardView.addSubview(statusLabel)

        emptyLabel.font = AppTheme.Fonts.body
        emptyLabel.textColor = AppTheme.Colors.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = "No databases found in this page.\n\nMake sure your Notion page contains databases."
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        cardView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            // Card constrained between header and button
            cardView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -16),

            cardTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            helpButton.centerYAnchor.constraint(equalTo: cardTitleLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),

            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            emptyLabel.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            emptyLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }

    // MARK: - Button Section (Bottom)
    private func setupButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Continue"
        config.image = UIImage(systemName: "arrow.right")
        config.imagePadding = 8
        config.imagePlacement = .trailing
        config.baseBackgroundColor = AppTheme.Colors.primaryBrown
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Fonts.buttonLarge
            return outgoing
        }

        continueButton.configuration = config
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.isHidden = true
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            // Continue button pinned to bottom
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func showHelpTapped() {
        let alert = UIAlertController(
            title: "Database Roles",
            message: """
            Each database in your Notion page needs a role:

            • **Expense** - Database for tracking expenses/outgoing money
            • **Income** - Database for tracking income/ incoming money
            • **Ignore** - Skip this database (not used for finance tracking)

            At least one database should be marked as Expense or Income.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
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
        backgroundColor = AppTheme.Colors.cardBackground
        selectionStyle = .none

        titleLabel.font = AppTheme.Fonts.bodyBold
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        segmentedControl.selectedSegmentTintColor = AppTheme.Colors.primaryBrown
        segmentedControl.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: AppTheme.Colors.textPrimary,
            .font: AppTheme.Fonts.captionMedium
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: AppTheme.Fonts.captionBold
        ], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
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
