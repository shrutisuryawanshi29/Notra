import UIKit

final class SplitTrackerViewController: UIViewController {

    private let viewModel = SplitTrackerViewModel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let totalPendingLabel = UILabel()
    private let totalSettledLabel = UILabel()
    private let headerStack = UIStackView()
    private let filterStack = UIStackView()
    private var filterChips: [UIButton] = []
    private let emptyStateLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        setupUI()
        viewModel.loadSplitTransactions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadSplitTransactions()
    }

    private func setupUI() {
        title = "Split Tracker"
        view.backgroundColor = AppTheme.Colors.background
        AppTheme.styleNavigationBar(navigationController?.navigationBar ?? UINavigationBar())

        // Header
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Who Owes You"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary

        totalPendingLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        totalPendingLabel.textColor = AppTheme.Colors.accent

        totalSettledLabel.font = AppTheme.Fonts.body
        totalSettledLabel.textColor = AppTheme.Colors.income

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(totalPendingLabel)
        headerStack.addArrangedSubview(totalSettledLabel)

        // Filter chips
        filterStack.axis = .horizontal
        filterStack.spacing = 8
        filterStack.distribution = .fillProportionally
        filterStack.translatesAutoresizingMaskIntoConstraints = false

        for filter in SplitTrackerFilter.allCases {
            let chip = UIButton(type: .system)
            chip.setTitle(filter.rawValue, for: .normal)
            chip.titleLabel?.font = AppTheme.Fonts.buttonSmall
            chip.layer.cornerRadius = 14
            chip.layer.borderWidth = 1
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            chip.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            chip.tag = SplitTrackerFilter.allCases.firstIndex(of: filter) ?? 0
            filterChips.append(chip)
            filterStack.addArrangedSubview(chip)
        }
        updateFilterChips()

        // Table
        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PersonGroupCell.self, forCellReuseIdentifier: "PersonGroupCell")
        tableView.register(EmptyCell.self, forCellReuseIdentifier: "EmptyCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateLabel.text = "No split expenses yet."
        emptyStateLabel.font = AppTheme.Fonts.body
        emptyStateLabel.textColor = AppTheme.Colors.textMuted
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true

        view.addSubview(headerStack)
        view.addSubview(filterStack)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            filterStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            filterStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            filterStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            filterStack.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: filterStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func filterTapped(_ sender: UIButton) {
        let filters = SplitTrackerFilter.allCases
        guard sender.tag < filters.count else { return }
        viewModel.activeFilter = filters[sender.tag]
        updateFilterChips()
    }

    private func updateFilterChips() {
        let filters = SplitTrackerFilter.allCases
        for (idx, chip) in filterChips.enumerated() {
            guard idx < filters.count else { continue }
            let isSelected = filters[idx] == viewModel.activeFilter
            if isSelected {
                chip.backgroundColor = AppTheme.Colors.accent
                chip.setTitleColor(AppTheme.Colors.buttonContent, for: .normal)
                chip.layer.borderColor = AppTheme.Colors.accent.cgColor
            } else {
                chip.backgroundColor = .clear
                chip.setTitleColor(AppTheme.Colors.textSecondary, for: .normal)
                chip.layer.borderColor = AppTheme.Colors.border.cgColor
            }
        }
    }

    private func openPersonDetail(group: SplitTrackerPersonGroup) {
        let detailVC = SplitTrackerPersonDetailViewController(
            personName: group.personName,
            entries: group.entries,
            viewModel: viewModel
        )
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func updateTotals() {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"

        if viewModel.totalPendingOwed > 0 {
            totalPendingLabel.text = "\(f.string(from: NSNumber(value: viewModel.totalPendingOwed)) ?? "$0.00") pending"
        } else {
            totalPendingLabel.text = "All settled"
            totalPendingLabel.textColor = AppTheme.Colors.income
        }

        if viewModel.totalSettled > 0 {
            totalSettledLabel.text = "\(f.string(from: NSNumber(value: viewModel.totalSettled)) ?? "$0.00") settled"
            totalSettledLabel.isHidden = false
        } else {
            totalSettledLabel.isHidden = true
        }

        emptyStateLabel.isHidden = !viewModel.isEmpty
        tableView.isHidden = viewModel.isEmpty
    }
}

extension SplitTrackerViewController: SplitTrackerViewModelDelegate {
    func didUpdateData() {
        tableView.reloadData()
        updateTotals()
    }

    func didStartLoading() {
        // Could show a spinner
    }

    func didFinishLoading() {
        tableView.reloadData()
        updateTotals()
    }

    func didFailUpdate(_ error: String) {
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension SplitTrackerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.personGroups.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PersonGroupCell", for: indexPath) as! PersonGroupCell
        let group = viewModel.personGroups[indexPath.section]
        cell.configure(with: group)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = viewModel.personGroups[indexPath.section]
        openPersonDetail(group: group)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        4
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView(frame: .zero)
    }
}

// MARK: - Person Group Cell

fileprivate class PersonGroupCell: UITableViewCell {
    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let pendingLabel = UILabel()
    private let countLabel = UILabel()
    private let chevronView = UIImageView()

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

        nameLabel.font = AppTheme.Fonts.bodyBold
        nameLabel.textColor = AppTheme.Colors.textPrimary

        pendingLabel.font = AppTheme.Fonts.body
        pendingLabel.textColor = AppTheme.Colors.accent

        countLabel.font = AppTheme.Fonts.caption
        countLabel.textColor = AppTheme.Colors.textMuted

        chevronView.image = UIImage(systemName: "chevron.right")
        chevronView.tintColor = AppTheme.Colors.textMuted
        chevronView.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [nameLabel, pendingLabel, countLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(textStack)
        containerView.addSubview(chevronView)

        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            chevronView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(with group: SplitTrackerPersonGroup) {
        nameLabel.text = group.personName
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        if group.pendingTotal > 0 {
            pendingLabel.text = "Owes \(f.string(from: NSNumber(value: group.pendingTotal)) ?? "$0.00")"
            if group.pendingCount == 1 {
                countLabel.text = "\(group.pendingCount) pending split"
            } else {
                countLabel.text = "\(group.pendingCount) pending splits"
            }
            pendingLabel.textColor = AppTheme.Colors.accent
        } else {
            pendingLabel.text = "All settled — \(f.string(from: NSNumber(value: group.settledTotal)) ?? "$0.00")"
            pendingLabel.textColor = AppTheme.Colors.income
            countLabel.text = "\(group.entries.count) split\(group.entries.count == 1 ? "" : "s")"
        }
    }
}

// MARK: - Empty Cell

fileprivate class EmptyCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
