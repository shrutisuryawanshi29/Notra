import UIKit

final class SplitTrackerPersonDetailViewController: UIViewController {

    private let personName: String
    private var entries: [SplitTrackerEntry]
    private let viewModel: SplitTrackerViewModel
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let pendingTotalLabel = UILabel()
    private let settledTotalLabel = UILabel()

    private var updatingEntryId: String?

    init(personName: String, entries: [SplitTrackerEntry], viewModel: SplitTrackerViewModel) {
        self.personName = personName
        self.entries = entries
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = personName
        view.backgroundColor = AppTheme.Colors.background
        AppTheme.styleNavigationBar(navigationController?.navigationBar ?? UINavigationBar())

        setupUI()
    }

    private func setupUI() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.backgroundColor = AppTheme.Colors.cardBackground

        let nameLabel = UILabel()
        nameLabel.text = personName
        nameLabel.font = AppTheme.Fonts.headingMedium
        nameLabel.textColor = AppTheme.Colors.textPrimary

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"

        let pendingTotal = entries.filter { $0.status == .pending }.reduce(0) { $0 + $1.amountOwed }
        let settledTotal = entries.filter { $0.status == .settled }.reduce(0) { $0 + $1.amountOwed }

        pendingTotalLabel.font = AppTheme.Fonts.body
        pendingTotalLabel.textColor = AppTheme.Colors.accent
        if pendingTotal > 0 {
            pendingTotalLabel.text = "Pending: \(f.string(from: NSNumber(value: pendingTotal)) ?? "$0.00")"
        } else {
            pendingTotalLabel.text = "No pending amounts"
            pendingTotalLabel.textColor = AppTheme.Colors.income
        }

        settledTotalLabel.font = AppTheme.Fonts.body
        settledTotalLabel.textColor = AppTheme.Colors.income
        if settledTotal > 0 {
            settledTotalLabel.text = "Settled: \(f.string(from: NSNumber(value: settledTotal)) ?? "$0.00")"
            settledTotalLabel.isHidden = false
        } else {
            settledTotalLabel.isHidden = true
        }

        headerStack.addArrangedSubview(nameLabel)
        headerStack.addArrangedSubview(pendingTotalLabel)
        headerStack.addArrangedSubview(settledTotalLabel)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(loadingIndicator)

        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SplitEntryCell.self, forCellReuseIdentifier: "SplitEntryCell")
        tableView.tableHeaderView = headerStack
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerStack.widthAnchor.constraint(equalTo: tableView.widthAnchor)
        ])

        // Calculate header height
        headerStack.layoutIfNeeded()
        let headerHeight = headerStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        headerStack.frame.size.height = headerHeight
        tableView.tableHeaderView = headerStack
    }

    private func openTransactionDetail(_ entry: SplitTrackerEntry) {
        let detailVC = TransactionDetailViewController(transaction: entry.transaction)
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
                    // Reload data from view model
                    self.entries = self.viewModel.personGroups.flatMap { $0.entries }.filter { $0.participantId == entry.participantId }
                    self.updateTotals()
                    self.tableView.reloadData()
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

    private func updateTotals() {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        let pendingTotal = entries.filter { $0.status == .pending }.reduce(0) { $0 + $1.amountOwed }
        let settledTotal = entries.filter { $0.status == .settled }.reduce(0) { $0 + $1.amountOwed }

        if pendingTotal > 0 {
            pendingTotalLabel.text = "Pending: \(f.string(from: NSNumber(value: pendingTotal)) ?? "$0.00")"
            pendingTotalLabel.textColor = AppTheme.Colors.accent
        } else {
            pendingTotalLabel.text = "No pending amounts"
            pendingTotalLabel.textColor = AppTheme.Colors.income
        }

        if settledTotal > 0 {
            settledTotalLabel.text = "Settled: \(f.string(from: NSNumber(value: settledTotal)) ?? "$0.00")"
            settledTotalLabel.isHidden = false
        } else {
            settledTotalLabel.isHidden = true
        }
    }
}

extension SplitTrackerPersonDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SplitEntryCell", for: indexPath) as! SplitEntryCell
        let entry = entries[indexPath.row]
        let isUpdating = updatingEntryId == entry.transactionId
        cell.configure(with: entry, isUpdating: isUpdating)
        cell.onSettleTap = { [weak self] in
            let newStatus: SettlementStatus = entry.status == .settled ? .pending : .settled
            self?.updateSettlement(for: entry, newStatus: newStatus)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openTransactionDetail(entries[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - Split Entry Cell

fileprivate class SplitEntryCell: UITableViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()
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
        containerView.layer.cornerRadius = AppTheme.CornerRadius.medium
        if AppTheme.currentMode == .dark {
            containerView.layer.borderWidth = 1
            containerView.layer.borderColor = AppTheme.Colors.border.cgColor
        }
        containerView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.Fonts.bodyBold
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 0

        dateLabel.font = AppTheme.Fonts.caption
        dateLabel.textColor = AppTheme.Colors.textSecondary

        categoryLabel.font = AppTheme.Fonts.small
        categoryLabel.textColor = AppTheme.Colors.textMuted

        amountLabel.font = AppTheme.Fonts.bodyBold
        amountLabel.textColor = AppTheme.Colors.accent
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)

        statusChip.titleLabel?.font = AppTheme.Fonts.smallMedium
        statusChip.layer.cornerRadius = 10
        statusChip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        statusChip.isUserInteractionEnabled = false

        actionButton.titleLabel?.font = AppTheme.Fonts.buttonSmall
        actionButton.layer.cornerRadius = 12
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [titleLabel, amountLabel])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .top

        let bottomRow = UIStackView(arrangedSubviews: [statusChip, actionButton])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [topRow, dateLabel, categoryLabel, bottomRow])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(textStack)
        containerView.addSubview(loadingSpinner)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            loadingSpinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    func configure(with entry: SplitTrackerEntry, isUpdating: Bool) {
        titleLabel.text = entry.transactionTitle

        let df = DateFormatter()
        df.dateStyle = .medium
        dateLabel.text = df.string(from: entry.date)

        if let cat = entry.category, !cat.isEmpty {
            categoryLabel.text = cat
            categoryLabel.isHidden = false
        } else {
            categoryLabel.isHidden = true
        }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        amountLabel.text = f.string(from: NSNumber(value: entry.amountOwed))

        if entry.status == .settled {
            statusChip.setTitle("Settled", for: .normal)
            statusChip.backgroundColor = AppTheme.Colors.income
            statusChip.setTitleColor(.white, for: .normal)
            statusChip.layer.borderColor = UIColor.clear.cgColor
            statusChip.layer.borderWidth = 0

            actionButton.setTitle("Undo Settled", for: .normal)
            actionButton.backgroundColor = AppTheme.Colors.cardBackgroundAlt
            actionButton.setTitleColor(AppTheme.Colors.warning, for: .normal)
            actionButton.layer.borderWidth = 1
            actionButton.layer.borderColor = AppTheme.Colors.border.cgColor
        } else {
            statusChip.setTitle("Pending", for: .normal)
            statusChip.backgroundColor = AppTheme.Colors.warning
            statusChip.setTitleColor(.white, for: .normal)
            statusChip.layer.borderColor = UIColor.clear.cgColor
            statusChip.layer.borderWidth = 0

            actionButton.setTitle("Mark Settled", for: .normal)
            actionButton.backgroundColor = AppTheme.Colors.income
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.layer.borderWidth = 0
        }

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
