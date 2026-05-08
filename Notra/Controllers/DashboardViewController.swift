//
//  DashboardViewController.swift
//  Notra
//

import UIKit

class DashboardViewController: UIViewController {

    private let viewModel: DashboardViewModel
    private var lastSyncDate: Date?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let headerView = UIView()
    private let greetingLabel = UILabel()
    private let lastSyncLabel = UILabel()

    private let monthSelectorButton = UIButton(type: .system)

    private let summaryStackView = UIStackView()
    private let spentCard = SummaryCardView()
    private let incomeCard = SummaryCardView()
    private let balanceCard = SummaryCardView()

    private let expenseButton = UIButton(type: .system)
    private let incomeButton = UIButton(type: .system)
    private let analyticsButton = UIButton(type: .system)

    private let loadingContainerView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let progressLabel = UILabel()

    private let emptyStateView = UIView()
    private let emptyStateLabel = UILabel()
    private let setupButton = UIButton(type: .system)

    init(token: String) {
        self.viewModel = DashboardViewModel(token: token)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.delegate = self
        viewModel.loadData()
    }

    private func setupUI() {
        title = "Dashboard"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )

        setupScrollView()
        setupHeader()
        setupMonthSelector()
        setupSummaryCards()
        setupButtons()
        setupLoadingView()
        setupEmptyState()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)

        greetingLabel.text = "Your Finances"
        greetingLabel.font = .systemFont(ofSize: 28, weight: .bold)
        greetingLabel.textColor = .label
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(greetingLabel)

        lastSyncLabel.text = "Pull to refresh"
        lastSyncLabel.font = .systemFont(ofSize: 13)
        lastSyncLabel.textColor = .secondaryLabel
        lastSyncLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(lastSyncLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            greetingLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            greetingLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            lastSyncLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 4),
            lastSyncLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            lastSyncLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }

    private func setupMonthSelector() {
        monthSelectorButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        monthSelectorButton.semanticContentAttribute = .forceRightToLeft
        monthSelectorButton.setTitle(" May 2026 ", for: .normal)
        monthSelectorButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        monthSelectorButton.setTitleColor(.white, for: .normal)
        monthSelectorButton.tintColor = .white
        monthSelectorButton.backgroundColor = .systemIndigo
        monthSelectorButton.layer.cornerRadius = 20
        monthSelectorButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        monthSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        monthSelectorButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
        contentView.addSubview(monthSelectorButton)

        NSLayoutConstraint.activate([
            monthSelectorButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            monthSelectorButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    private func setupSummaryCards() {
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 12
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(summaryStackView)

        spentCard.configure(title: "Total Spent", icon: "arrow.up.circle.fill", color: .systemRed)
        incomeCard.configure(title: "Total Income", icon: "arrow.down.circle.fill", color: .systemGreen)
        balanceCard.configure(title: "Net Balance", icon: "wallet.pass.fill", color: .systemBlue)

        summaryStackView.addArrangedSubview(spentCard)
        summaryStackView.addArrangedSubview(incomeCard)
        summaryStackView.addArrangedSubview(balanceCard)

        NSLayoutConstraint.activate([
            summaryStackView.topAnchor.constraint(equalTo: monthSelectorButton.bottomAnchor, constant: 24),
            summaryStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            summaryStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupButtons() {
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStackView)

        configureActionButton(expenseButton, title: "View Expenses", icon: "creditcard.fill", color: .systemRed)
        configureActionButton(incomeButton, title: "View Income", icon: "banknote.fill", color: .systemGreen)
        configureActionButton(analyticsButton, title: "Analytics", icon: "chart.bar.fill", color: .systemIndigo)

        expenseButton.addTarget(self, action: #selector(viewExpensesTapped), for: .touchUpInside)
        incomeButton.addTarget(self, action: #selector(viewIncomeTapped), for: .touchUpInside)
        analyticsButton.addTarget(self, action: #selector(analyticsTapped), for: .touchUpInside)

        buttonStackView.addArrangedSubview(expenseButton)
        buttonStackView.addArrangedSubview(incomeButton)
        buttonStackView.addArrangedSubview(analyticsButton)

        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 32),
            buttonStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])

        [expenseButton, incomeButton, analyticsButton].forEach { button in
            button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }
    }

    private func configureActionButton(_ button: UIButton, title: String, icon: String, color: UIColor) {
        button.setTitle("  \(title)", for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.12)
        button.setTitleColor(color, for: .normal)
        button.tintColor = color
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 14
    }

    private func setupLoadingView() {
        loadingContainerView.backgroundColor = .systemGroupedBackground
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.isHidden = true
        view.addSubview(loadingContainerView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        loadingContainerView.addSubview(activityIndicator)

        progressLabel.textAlignment = .center
        progressLabel.font = .systemFont(ofSize: 15, weight: .medium)
        progressLabel.textColor = .secondaryLabel
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            loadingContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor, constant: -20),

            progressLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
        ])
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        let emptyIcon = UIImageView(image: UIImage(systemName: "doc.text.magnifyingglass"))
        emptyIcon.tintColor = .tertiaryLabel
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyIcon)

        emptyStateLabel.text = "No data found"
        emptyStateLabel.font = .systemFont(ofSize: 18, weight: .medium)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyStateLabel)

        setupButton.setTitle("Go to Setup", for: .normal)
        setupButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        setupButton.backgroundColor = .systemIndigo
        setupButton.setTitleColor(.white, for: .normal)
        setupButton.layer.cornerRadius = 12
        setupButton.translatesAutoresizingMaskIntoConstraints = false
        setupButton.addTarget(self, action: #selector(goToSetup), for: .touchUpInside)
        emptyStateView.addSubview(setupButton)

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            emptyIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyIcon.heightAnchor.constraint(equalToConstant: 60),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 16),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            setupButton.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 24),
            setupButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            setupButton.widthAnchor.constraint(equalToConstant: 160),
            setupButton.heightAnchor.constraint(equalToConstant: 48),
            setupButton.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }

    @objc private func refreshTapped() {
        viewModel.loadData()
    }

    @objc private func monthSelectorTapped() {
        let alert = UIAlertController(title: "Select Month", message: nil, preferredStyle: .actionSheet)

        for month in viewModel.availableMonths {
            let monthName = viewModel.getMonthDisplayString(for: month)
            alert.addAction(UIAlertAction(title: monthName, style: .default) { [weak self] _ in
                self?.viewModel.selectMonth(month)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = monthSelectorButton
            popover.sourceRect = monthSelectorButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func viewExpensesTapped() {
        let vc = ExpenseListViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func viewIncomeTapped() {
        let vc = IncomeListViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func analyticsTapped() {
        let alert = UIAlertController(title: "Coming Soon", message: "Analytics and charts are under development.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func goToSetup() {
        navigationController?.popToRootViewController(animated: true)
    }

    private func updateUI() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        let monthDisplay = viewModel.getMonthDisplayString(for: viewModel.selectedMonth)
        monthSelectorButton.setTitle(" \(monthDisplay) ", for: .normal)

        spentCard.setValue(formatter.string(from: NSNumber(value: viewModel.selectedMonthExpenses)) ?? "$0.00")
        spentCard.setSubtitle("\(viewModel.selectedMonthExpensesCount) transactions")

        incomeCard.setValue(formatter.string(from: NSNumber(value: viewModel.selectedMonthIncomes)) ?? "$0.00")
        incomeCard.setSubtitle("\(viewModel.selectedMonthIncomesCount) transactions")

        let balance = viewModel.balance
        let balanceColor: UIColor = balance >= 0 ? .systemGreen : .systemRed
        let balancePrefix = balance >= 0 ? "+" : "-"
        let balanceValue = formatter.string(from: NSNumber(value: abs(balance))) ?? "$0.00"
        balanceCard.setValue("\(balancePrefix)\(balanceValue)")
        balanceCard.setValueColor(balanceColor)
        balanceCard.setSubtitle(balance >= 0 ? "You saved this month" : "Over budget")

        if let lastSync = lastSyncDate {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            lastSyncLabel.text = "Last synced at \(timeFormatter.string(from: lastSync))"
        }
    }
}

extension DashboardViewController: DashboardViewModelDelegate {
    func didStartLoading() {
        lastSyncDate = nil
        loadingContainerView.isHidden = false
        scrollView.isHidden = true
        emptyStateView.isHidden = true
        activityIndicator.startAnimating()
        progressLabel.text = "Loading your finances..."
    }

    func didFinishLoading(success: Bool, error: Error?) {
        loadingContainerView.isHidden = true
        activityIndicator.stopAnimating()
        progressLabel.text = ""

        if success {
            lastSyncDate = Date()

            let hasData = viewModel.selectedMonthExpensesCount > 0 || viewModel.selectedMonthIncomesCount > 0

            if hasData {
                scrollView.isHidden = false
                emptyStateView.isHidden = true
                updateUI()
            } else {
                scrollView.isHidden = true
                emptyStateView.isHidden = false
                emptyStateLabel.text = "No transactions this month"
            }
        } else {
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateLabel.text = error?.localizedDescription ?? "Failed to load data"
            setupButton.setTitle("Try Again", for: .normal)
            setupButton.removeTarget(self, action: #selector(goToSetup), for: .touchUpInside)
            setupButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        }
    }

    func didUpdateProgress(current: Int, total: Int) {
        progressLabel.text = "Loading \(current) of \(total) databases..."
    }

    func didUpdateMonthSelection() {
        updateUI()
    }
}

class SummaryCardView: UIView {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        iconContainer.layer.cornerRadius = 22
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 100),

            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),

            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14)
        ])
    }

    func configure(title: String, icon: String, color: UIColor) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        iconContainer.backgroundColor = color
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }

    func setValueColor(_ color: UIColor) {
        valueLabel.textColor = color
    }

    func setSubtitle(_ subtitle: String) {
        subtitleLabel.text = subtitle
    }
}