import UIKit

final class SplitTrackerPersonDetailViewController: UIViewController {

    private let personName: String
    private let allEntries: [SplitTrackerEntry]
    private var filteredEntries: [SplitTrackerEntry] = []
    private let selectedFilter: SplitTrackerFilter
    private let viewModel: SplitTrackerViewModel
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let pendingTotalLabel = UILabel()
    private let settledTotalLabel = UILabel()
    private let contextSubtitleLabel = UILabel()
    private let headerView = UIView()
    private let emptyStateLabel = UILabel()

    private var updatingEntryId: String?

    init(personName: String, entries: [SplitTrackerEntry], selectedFilter: SplitTrackerFilter, viewModel: SplitTrackerViewModel) {
        self.personName = personName
        self.allEntries = entries
        self.selectedFilter = selectedFilter
        self.viewModel = viewModel
        self.filteredEntries = Self.filterEntries(entries, by: selectedFilter)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func filterEntries(_ entries: [SplitTrackerEntry], by filter: SplitTrackerFilter) -> [SplitTrackerEntry] {
        switch filter {
        case .pending: return entries.filter { $0.status == .pending }
        case .settled: return entries.filter { $0.status == .settled }
        case .all: return entries
        }
    }

    private func refreshEntries() {
        let nameLower = personName.lowercased()
        let refreshed = viewModel.allGroups.first { $0.personName.lowercased() == nameLower }?.entries ?? allEntries
        filteredEntries = Self.filterEntries(refreshed, by: viewModel.activeFilter)
        updateHeader()
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = personName
        view.backgroundColor = AppTheme.Colors.background
        AppTheme.styleNavigationBar(navigationController?.navigationBar ?? UINavigationBar())

        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshEntries()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView, tableView.bounds.width > 0 else { return }
        let targetWidth = tableView.bounds.width
        let size = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if abs(header.frame.height - size.height) > 0.5 {
            header.frame.size.height = size.height
            tableView.tableHeaderView = header
        }
    }

    private func setupUI() {
        headerView.backgroundColor = .clear
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = personName
        nameLabel.font = AppTheme.Fonts.headingMedium
        nameLabel.textColor = AppTheme.Colors.textPrimary

        pendingTotalLabel.font = AppTheme.Fonts.body
        pendingTotalLabel.textColor = AppTheme.Colors.accent
        settledTotalLabel.font = AppTheme.Fonts.caption
        settledTotalLabel.textColor = AppTheme.Colors.income

        contextSubtitleLabel.font = AppTheme.Fonts.caption
        contextSubtitleLabel.textColor = AppTheme.Colors.textMuted

        let totalsStack = UIStackView(arrangedSubviews: [pendingTotalLabel, settledTotalLabel])
        totalsStack.axis = .vertical
        totalsStack.spacing = 2

        let headerContent = UIStackView(arrangedSubviews: [nameLabel, totalsStack, contextSubtitleLabel])
        headerContent.axis = .vertical
        headerContent.spacing = 8
        headerContent.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(headerContent)

        NSLayoutConstraint.activate([
            headerContent.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            headerContent.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            headerContent.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            headerContent.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            loadingIndicator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20)
        ])

        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SplitEntryCell.self, forCellReuseIdentifier: "SplitEntryCell")
        tableView.tableHeaderView = headerView
        tableView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateLabel.font = AppTheme.Fonts.body
        emptyStateLabel.textColor = AppTheme.Colors.textMuted
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true

        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        updateHeader()

        let fitting = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        headerView.frame.size = fitting
        tableView.tableHeaderView = headerView
    }

    private func openTransactionDetail(_ entry: SplitTrackerEntry) {
        let detailVC = TransactionDetailViewController(transaction: entry.transaction)
        print("[SplitTrackerDetail] Edit tapped entryId=\(entry.transactionId), pageId=\(entry.transaction.id)")
        detailVC.onEdit = { [weak self] tx in
            guard let self = self else { return }
            print("[SplitTrackerDetail] fullTransactionFound=true")
            print("[SplitTrackerDetail] presenting edit transaction pageId=\(tx.id)")
            let editVC = AddTransactionViewController(
                prefillData: [:],
                initialRole: tx.databaseRole,
                editingTransaction: tx
            )
            editVC.onEditComplete = { [weak self] updatedTx, oldMonthKey in
                guard let self = self else { return }
                print("[SplitTrackerDetail] edit completed, refreshing tracker")
                SessionCacheManager.shared.replaceExpense(updatedTx)
                self.refreshEntries()
            }
            let editNav = UINavigationController(rootViewController: editVC)
            editNav.modalPresentationStyle = .fullScreen
            self.present(editNav, animated: true)
        }
        let nav = UINavigationController(rootViewController: detailVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func updateSettlement(for entry: SplitTrackerEntry, newStatus: SettlementStatus) {
        guard updatingEntryId == nil else { return }
        updatingEntryId = entry.transactionId
        loadingIndicator.startAnimating()

        viewModel.updateSettlementStatus(entry: entry, newStatus: newStatus) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updatingEntryId = nil
                self.loadingIndicator.stopAnimating()
                switch result {
                case .success:
                    self.refreshEntries()
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Could not update settlement status. Please try again.\n\(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func updateHeader() {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"

        let pendingTotal = filteredEntries.filter { $0.status == .pending }.reduce(0) { $0 + $1.amountOwed }
        let settledTotal = filteredEntries.filter { $0.status == .settled }.reduce(0) { $0 + $1.amountOwed }

        switch selectedFilter {
        case .pending:
            if pendingTotal > 0 {
                pendingTotalLabel.text = "Pending: \(f.string(from: NSNumber(value: pendingTotal)) ?? "$0.00")"
                pendingTotalLabel.textColor = AppTheme.Colors.accent
            } else {
                pendingTotalLabel.text = "No pending"
                pendingTotalLabel.textColor = AppTheme.Colors.textMuted
            }
            settledTotalLabel.isHidden = true
            contextSubtitleLabel.text = "Showing pending splits"
        case .settled:
            pendingTotalLabel.text = "Settled: \(f.string(from: NSNumber(value: settledTotal)) ?? "$0.00")"
            pendingTotalLabel.textColor = AppTheme.Colors.income
            settledTotalLabel.isHidden = true
            contextSubtitleLabel.text = "Showing settled splits"
        case .all:
            if pendingTotal > 0 {
                pendingTotalLabel.text = "Pending: \(f.string(from: NSNumber(value: pendingTotal)) ?? "$0.00")"
                pendingTotalLabel.textColor = AppTheme.Colors.accent
            } else {
                pendingTotalLabel.text = "No pending"
                pendingTotalLabel.textColor = AppTheme.Colors.textMuted
            }
            if settledTotal > 0 {
                settledTotalLabel.text = "Settled: \(f.string(from: NSNumber(value: settledTotal)) ?? "$0.00")"
                settledTotalLabel.isHidden = false
            } else {
                settledTotalLabel.isHidden = true
            }
            contextSubtitleLabel.text = "Showing all splits"
        }

        let emptyMessage: String
        if filteredEntries.isEmpty {
            switch selectedFilter {
            case .pending: emptyMessage = "No pending splits."
            case .settled: emptyMessage = "No settled splits yet."
            case .all: emptyMessage = "No split records yet."
            }
        } else {
            emptyMessage = ""
        }
        emptyStateLabel.text = emptyMessage
        emptyStateLabel.isHidden = !filteredEntries.isEmpty
        tableView.isHidden = filteredEntries.isEmpty
    }
}

extension SplitTrackerPersonDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SplitEntryCell", for: indexPath) as! SplitEntryCell
        let entry = filteredEntries[indexPath.row]
        let isUpdating = updatingEntryId == entry.transactionId
        cell.configure(with: entry, isUpdating: isUpdating)
        cell.onSettleTap = { [weak self] in
            guard let self = self else { return }
            let newStatus: SettlementStatus = entry.status == .settled ? .pending : .settled
            self.updateSettlement(for: entry, newStatus: newStatus)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openTransactionDetail(filteredEntries[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }
}

// MARK: - Split Entry Cell

fileprivate class SplitEntryCell: UITableViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()
    private let splitContextLabel = UILabel()
    private let statusChip = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)

    var onSettleTap: (() -> Void)?

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
        if AppTheme.currentMode == .dark {
            containerView.layer.borderWidth = 1
            containerView.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        AppTheme.Shadow.applyCard(to: containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.Fonts.bodyBold
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        dateLabel.font = AppTheme.Fonts.caption
        dateLabel.textColor = AppTheme.Colors.textSecondary

        categoryLabel.font = AppTheme.Fonts.small
        categoryLabel.textColor = AppTheme.Colors.textMuted

        amountLabel.font = AppTheme.Fonts.headingMedium
        amountLabel.textColor = AppTheme.Colors.accent
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        splitContextLabel.font = AppTheme.Fonts.small
        splitContextLabel.textColor = AppTheme.Colors.textMuted
        splitContextLabel.numberOfLines = 1

        statusChip.titleLabel?.font = AppTheme.Fonts.smallMedium
        statusChip.layer.cornerRadius = 10
        statusChip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        statusChip.isUserInteractionEnabled = false

        actionButton.titleLabel?.font = AppTheme.Fonts.smallMedium
        actionButton.layer.cornerRadius = 10
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)

        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [titleLabel, amountLabel])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .firstBaseline

        let metaRow = UIStackView(arrangedSubviews: [dateLabel, categoryLabel])
        metaRow.axis = .horizontal
        metaRow.spacing = 6

        let bottomRow = UIStackView(arrangedSubviews: [statusChip, UIView(), actionButton])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [topRow, metaRow, splitContextLabel, bottomRow])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(textStack)
        containerView.addSubview(loadingSpinner)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),

            loadingSpinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    func configure(with entry: SplitTrackerEntry, isUpdating: Bool) {
        titleLabel.text = entry.transactionTitle

        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        dateLabel.text = df.string(from: entry.date)

        if let cat = entry.category, !cat.isEmpty {
            categoryLabel.text = "• \(cat)"
            categoryLabel.isHidden = false
        } else {
            categoryLabel.isHidden = true
        }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        amountLabel.text = f.string(from: NSNumber(value: entry.amountOwed))

        let split = entry.splitMetadata
        if split.paidAmount > 0 {
            let paidStr = f.string(from: NSNumber(value: split.paidAmount)) ?? "$0.00"
            let myShare = split.myShare
            if let participant = split.participants?.first(where: { $0.id == entry.participantId }) {
                let theirOwes = f.string(from: NSNumber(value: participant.owes)) ?? "$0.00"
                splitContextLabel.text = "Paid: \(paidStr) • Their share: \(theirOwes)"
            } else {
                let myStr = f.string(from: NSNumber(value: myShare)) ?? "$0.00"
                splitContextLabel.text = "Paid: \(paidStr) • Your share: \(myStr)"
            }
            splitContextLabel.isHidden = false
        } else {
            splitContextLabel.isHidden = true
        }

        if entry.status == .settled {
            statusChip.setTitle("Settled", for: .normal)
            statusChip.backgroundColor = AppTheme.Colors.income
            statusChip.setTitleColor(.white, for: .normal)
            statusChip.layer.borderWidth = 0

            actionButton.setTitle("Undo", for: .normal)
            actionButton.backgroundColor = .clear
            actionButton.setTitleColor(AppTheme.Colors.textSecondary, for: .normal)
            actionButton.layer.borderWidth = 1
            actionButton.layer.borderColor = AppTheme.Colors.border.cgColor
        } else {
            statusChip.setTitle("Pending", for: .normal)
            statusChip.backgroundColor = AppTheme.Colors.warning
            statusChip.setTitleColor(.white, for: .normal)
            statusChip.layer.borderWidth = 0

            actionButton.setTitle("Settle", for: .normal)
            actionButton.backgroundColor = AppTheme.Colors.income
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.layer.borderWidth = 0
        }

        amountLabel.textColor = entry.status == .settled ? AppTheme.Colors.textMuted : AppTheme.Colors.accent

        if isUpdating {
            loadingSpinner.startAnimating()
            actionButton.isHidden = true
        } else {
            loadingSpinner.stopAnimating()
            actionButton.isHidden = false
        }
    }

    @objc private func actionTapped() {
        onSettleTap?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSettleTap = nil
        loadingSpinner.stopAnimating()
        actionButton.isHidden = false
    }
}
