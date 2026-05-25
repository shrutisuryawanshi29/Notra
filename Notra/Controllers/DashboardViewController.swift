//
//  DashboardViewController.swift
//  Notra
//

import UIKit

class DashboardViewController: UIViewController {

    let viewModel: DashboardViewModel
    private var lastSyncDate: Date?

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = AppTheme.Colors.background
        return sv
    }()
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        return view
    }()

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

    private let statusCardView = StatusCardView()
    private let activityCardView = ActivityCardView()
    private let quickChecksCardView = QuickChecksCardView()
    private let actionsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Actions"
        label.font = AppTheme.Fonts.captionBold
        label.textColor = AppTheme.Colors.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        return view
    }()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let progressLabel = UILabel()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        return view
    }()
    private let emptyStateLabel = UILabel()
    private let setupButton = UIButton(type: .system)

    private let fabButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = AppTheme.Colors.accent
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        view.backgroundColor = AppTheme.Colors.background

        AppTheme.styleNavigationBar(navigationController!.navigationBar)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.Colors.primaryBrown

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = AppTheme.Colors.primaryBrown

        setupScrollView()
        setupHeader()
        setupMonthSelector()
        setupSummaryCards()
        setupStatusCard()
        setupActivityCard()
        setupQuickChecksCard()
        setupActionsSection()
        setupLoadingView()
        setupEmptyState()
        setupFAB()
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
        greetingLabel.font = AppTheme.Fonts.headingLarge
        greetingLabel.textColor = AppTheme.Colors.textPrimary
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(greetingLabel)

        lastSyncLabel.text = "Pull to refresh"
        lastSyncLabel.font = AppTheme.Fonts.smallMedium
        lastSyncLabel.textColor = AppTheme.Colors.textMuted
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
        monthSelectorButton.titleLabel?.font = AppTheme.Fonts.bodyBold
        monthSelectorButton.setTitleColor(.white, for: .normal)
        monthSelectorButton.tintColor = .white
        monthSelectorButton.backgroundColor = AppTheme.Colors.primaryBrown
        monthSelectorButton.layer.cornerRadius = AppTheme.CornerRadius.pill
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

        spentCard.configure(title: "Total Spent", icon: "arrow.up.circle.fill", color: AppTheme.Colors.expense)
        incomeCard.configure(title: "Total Income", icon: "arrow.down.circle.fill", color: AppTheme.Colors.income)
        balanceCard.configure(title: "Net Balance", icon: "wallet.pass.fill", color: AppTheme.Colors.accent)

        summaryStackView.addArrangedSubview(spentCard)
        summaryStackView.addArrangedSubview(incomeCard)
        summaryStackView.addArrangedSubview(balanceCard)

        NSLayoutConstraint.activate([
            summaryStackView.topAnchor.constraint(equalTo: monthSelectorButton.bottomAnchor, constant: 24),
            summaryStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            summaryStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupActionsSection() {
        contentView.addSubview(actionsTitleLabel)
        contentView.addSubview(expenseButton)
        contentView.addSubview(incomeButton)
        contentView.addSubview(analyticsButton)

        expenseButton.translatesAutoresizingMaskIntoConstraints = false
        incomeButton.translatesAutoresizingMaskIntoConstraints = false
        analyticsButton.translatesAutoresizingMaskIntoConstraints = false

        configureActionButton(expenseButton, title: "View Expenses", icon: "creditcard.fill", color: AppTheme.Colors.expense)
        configureActionButton(incomeButton, title: "View Income", icon: "banknote.fill", color: AppTheme.Colors.income)
        configureActionButton(analyticsButton, title: "Analytics", icon: "chart.bar.fill", color: AppTheme.Colors.primaryBrown)

        expenseButton.addTarget(self, action: #selector(viewExpensesTapped), for: .touchUpInside)
        incomeButton.addTarget(self, action: #selector(viewIncomeTapped), for: .touchUpInside)
        analyticsButton.addTarget(self, action: #selector(analyticsTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            actionsTitleLabel.topAnchor.constraint(equalTo: quickChecksCardView.bottomAnchor, constant: 28),
            actionsTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            expenseButton.topAnchor.constraint(equalTo: actionsTitleLabel.bottomAnchor, constant: 12),
            expenseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            expenseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            expenseButton.heightAnchor.constraint(equalToConstant: 56),

            incomeButton.topAnchor.constraint(equalTo: expenseButton.bottomAnchor, constant: 12),
            incomeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            incomeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            incomeButton.heightAnchor.constraint(equalToConstant: 56),

            analyticsButton.topAnchor.constraint(equalTo: incomeButton.bottomAnchor, constant: 12),
            analyticsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            analyticsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            analyticsButton.heightAnchor.constraint(equalToConstant: 56),
            analyticsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func setupStatusCard() {
        statusCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusCardView)

        NSLayoutConstraint.activate([
            statusCardView.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 24),
            statusCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupActivityCard() {
        activityCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityCardView)

        NSLayoutConstraint.activate([
            activityCardView.topAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: 24),
            activityCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            activityCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupQuickChecksCard() {
        quickChecksCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quickChecksCardView)

        NSLayoutConstraint.activate([
            quickChecksCardView.topAnchor.constraint(equalTo: activityCardView.bottomAnchor, constant: 24),
            quickChecksCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickChecksCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func configureActionButton(_ button: UIButton, title: String, icon: String, color: UIColor) {
        button.setTitle("  \(title)", for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.12)
        button.setTitleColor(color, for: .normal)
        button.tintColor = color
        button.titleLabel?.font = AppTheme.Fonts.bodyBold
        button.layer.cornerRadius = AppTheme.CornerRadius.button
    }

    private func setupLoadingView() {
        loadingContainerView.backgroundColor = AppTheme.Colors.background
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.isHidden = true
        view.addSubview(loadingContainerView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        loadingContainerView.addSubview(activityIndicator)

        progressLabel.textAlignment = .center
        progressLabel.font = AppTheme.Fonts.bodyMedium
        progressLabel.textColor = AppTheme.Colors.textSecondary
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
        emptyIcon.tintColor = AppTheme.Colors.textMuted
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyIcon)

        emptyStateLabel.text = "No data found"
        emptyStateLabel.font = AppTheme.Fonts.headingMedium
        emptyStateLabel.textColor = AppTheme.Colors.textSecondary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyStateLabel)

        setupButton.setTitle("Go to Setup", for: .normal)
        setupButton.titleLabel?.font = AppTheme.Fonts.buttonMedium
        AppTheme.applyPrimaryButtonStyle(to: setupButton)
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
        let vc = AnalyticsViewController(month: viewModel.selectedMonth)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func settingsTapped() {
        let vc = SettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func goToSetup() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func addTransactionTapped() {
        let vc = AddTransactionViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func setupFAB() {
        fabButton.addTarget(self, action: #selector(addTransactionTapped), for: .touchUpInside)
        view.addSubview(fabButton)

        NSLayoutConstraint.activate([
            fabButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            fabButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            fabButton.widthAnchor.constraint(equalToConstant: 56),
            fabButton.heightAnchor.constraint(equalToConstant: 56)
        ])
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
        let balanceColor: UIColor = balance >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense
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

        updateStatusCard()
        updateActivityCard()
        updateQuickChecksCard()
    }

    private func updateStatusCard() {
        let info = viewModel.statusInfo
        statusCardView.configure(with: info)
    }

    private func updateActivityCard() {
        activityCardView.configure(with: viewModel.recentTransactions)
    }

    private func updateQuickChecksCard() {
        quickChecksCardView.configure(
            largestExpense: viewModel.largestExpense,
            mostUsedCategory: viewModel.mostUsedCategory,
            uncategorizedCount: viewModel.uncategorizedCount
        )
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
                let monthName = viewModel.getMonthDisplayString(for: viewModel.selectedMonth)
                emptyStateLabel.text = "No transactions for \(monthName)"
                setupButton.setTitle("Select Different Month", for: .normal)
                setupButton.removeTarget(self, action: #selector(goToSetup), for: .touchUpInside)
                setupButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
            }
        } else {
            scrollView.isHidden = true
            emptyStateView.isHidden = false

            let errorMessage = error?.localizedDescription ?? ""
            if errorMessage.lowercased().contains("no configured") {
                emptyStateLabel.text = "No databases configured.\n\nGo to Setup to add your finance databases."
                setupButton.setTitle("Go to Setup", for: .normal)
                setupButton.removeTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
                setupButton.addTarget(self, action: #selector(goToSetup), for: .touchUpInside)
            } else {
                emptyStateLabel.text = "Couldn't load your finances.\n\nPlease try again."
                setupButton.setTitle("Try Again", for: .normal)
                setupButton.removeTarget(self, action: #selector(goToSetup), for: .touchUpInside)
                setupButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
            }
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
        AppTheme.applyCardStyle(to: self)

        iconContainer.layer.cornerRadius = 22
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = AppTheme.Fonts.captionBold
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        valueLabel.font = AppTheme.Fonts.headingLargeRounded
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        subtitleLabel.font = AppTheme.Fonts.smallMedium
        subtitleLabel.textColor = AppTheme.Colors.textMuted
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

// MARK: - This Month Status Card

class StatusCardView: UIView {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let mainTextLabel = UILabel()
    private let subTextLabel = UILabel()
    private let footerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        AppTheme.applyCardStyle(to: self)

        iconContainer.layer.cornerRadius = 18
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconContainer)

        iconImageView.image = UIImage(systemName: "chart.pie.fill")
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.text = "This Month Status"
        titleLabel.font = AppTheme.Fonts.captionBold
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        mainTextLabel.font = AppTheme.Fonts.headingMedium
        mainTextLabel.textColor = AppTheme.Colors.textPrimary
        mainTextLabel.numberOfLines = 0
        mainTextLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainTextLabel)

        subTextLabel.font = AppTheme.Fonts.body
        subTextLabel.textColor = AppTheme.Colors.textMuted
        subTextLabel.numberOfLines = 0
        subTextLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subTextLabel)

        footerLabel.font = AppTheme.Fonts.smallMedium
        footerLabel.textColor = AppTheme.Colors.textMuted
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(footerLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            mainTextLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            mainTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            subTextLabel.topAnchor.constraint(equalTo: mainTextLabel.bottomAnchor, constant: 4),
            subTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            footerLabel.topAnchor.constraint(equalTo: subTextLabel.bottomAnchor, constant: 12),
            footerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(with info: DashboardStatusInfo) {
        titleLabel.text = "This Month Status"
        mainTextLabel.text = info.mainText
        subTextLabel.text = info.subText
        footerLabel.text = info.footerText

        if info.balance > 0 && info.hasIncome {
            mainTextLabel.textColor = AppTheme.Colors.income
            iconContainer.backgroundColor = AppTheme.Colors.income
        } else if info.balance < 0 && info.hasIncome {
            mainTextLabel.textColor = AppTheme.Colors.expense
            iconContainer.backgroundColor = AppTheme.Colors.expense
        } else {
            mainTextLabel.textColor = AppTheme.Colors.textPrimary
            iconContainer.backgroundColor = AppTheme.Colors.accent
        }
    }
}

// MARK: - Recent Activity Card

class ActivityCardView: UIView {
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private let emptyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Recent Activity"
        titleLabel.font = AppTheme.Fonts.captionBold
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        emptyLabel.text = "No activity this month yet.\nAdd an expense or income to get started."
        emptyLabel.font = AppTheme.Fonts.body
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            emptyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            emptyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    func configure(with transactions: [NormalizedTransaction]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if transactions.isEmpty {
            emptyLabel.isHidden = false
            stackView.isHidden = true
            return
        }

        emptyLabel.isHidden = true
        stackView.isHidden = false

        for (index, transaction) in transactions.enumerated() {
            let row = ActivityRowView(transaction: transaction)
            stackView.addArrangedSubview(row)

            if index < transactions.count - 1 {
                let separator = UIView()
                separator.backgroundColor = AppTheme.Colors.border
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stackView.addArrangedSubview(separator)
            }
        }
    }
}

class ActivityRowView: UIView {
    private let dotView = UIView()
    private let titleLabel = UILabel()
    private let categoryDateLabel = UILabel()
    private let amountLabel = UILabel()

    init(transaction: NormalizedTransaction) {
        super.init(frame: .zero)
        setupView()
        configure(with: transaction)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        dotView.layer.cornerRadius = 4
        dotView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotView)

        titleLabel.font = AppTheme.Fonts.bodyMedium
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        categoryDateLabel.font = AppTheme.Fonts.small
        categoryDateLabel.textColor = AppTheme.Colors.textMuted
        categoryDateLabel.numberOfLines = 1
        categoryDateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(categoryDateLabel)

        amountLabel.font = AppTheme.Fonts.bodyBold
        amountLabel.textAlignment = .right
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(amountLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            dotView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),

            categoryDateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            categoryDateLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            categoryDateLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            categoryDateLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func configure(with transaction: NormalizedTransaction) {
        titleLabel.text = transaction.title

        let category = transaction.category ?? "Uncategorized"
        let dateText = formatRelativeDate(transaction.date)
        categoryDateLabel.text = "\(category) · \(dateText)"

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formattedAmt = formatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00"

        if transaction.databaseRole == .expense {
            dotView.backgroundColor = AppTheme.Colors.expense
            amountLabel.textColor = AppTheme.Colors.expense
            amountLabel.text = "-\(formattedAmt)"
        } else {
            dotView.backgroundColor = AppTheme.Colors.income
            amountLabel.textColor = AppTheme.Colors.income
            amountLabel.text = "+\(formattedAmt)"
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Quick Checks Card

class QuickChecksCardView: UIView {
    private let titleLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Quick Checks"
        titleLabel.font = AppTheme.Fonts.captionBold
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(largestExpense: NormalizedTransaction?,
                   mostUsedCategory: (name: String, count: Int)?,
                   uncategorizedCount: Int) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let expense = largestExpense {
            let row = QuickCheckRowView(
                icon: "arrow.up.circle.fill",
                iconColor: AppTheme.Colors.expense,
                label: "Largest expense",
                value: "\(expense.title) · \(expense.formattedAmount)"
            )
            stackView.addArrangedSubview(row)
        } else {
            let row = QuickCheckRowView(
                icon: "arrow.up.circle.fill",
                iconColor: AppTheme.Colors.textMuted,
                label: "Largest expense",
                value: "No expenses yet"
            )
            stackView.addArrangedSubview(row)
        }

        if let category = mostUsedCategory {
            let row = QuickCheckRowView(
                icon: "tag.fill",
                iconColor: AppTheme.Colors.accent,
                label: "Most used category",
                value: "\(category.name) · \(category.count) transactions"
            )
            stackView.addArrangedSubview(row)
        } else {
            let row = QuickCheckRowView(
                icon: "tag.fill",
                iconColor: AppTheme.Colors.textMuted,
                label: "Most used category",
                value: "No category data"
            )
            stackView.addArrangedSubview(row)
        }

        if uncategorizedCount > 0 {
            let row = QuickCheckRowView(
                icon: "exclamationmark.triangle.fill",
                iconColor: AppTheme.Colors.expense,
                label: "Needs attention",
                value: "\(uncategorizedCount) uncategorized"
            )
            stackView.addArrangedSubview(row)
        } else {
            let row = QuickCheckRowView(
                icon: "checkmark.circle.fill",
                iconColor: AppTheme.Colors.income,
                label: "Categorization",
                value: "Everything categorized"
            )
            stackView.addArrangedSubview(row)
        }
    }
}

class QuickCheckRowView: UIView {
    private let iconImageView = UIImageView()
    private let labelLabel = UILabel()
    private let valueLabel = UILabel()

    init(icon: String, iconColor: UIColor, label: String, value: String) {
        super.init(frame: .zero)
        setupView()
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = iconColor
        labelLabel.text = label
        valueLabel.text = value
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        labelLabel.font = AppTheme.Fonts.bodyMedium
        labelLabel.textColor = AppTheme.Colors.textPrimary
        labelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelLabel)

        valueLabel.font = AppTheme.Fonts.smallMedium
        valueLabel.textColor = AppTheme.Colors.textMuted
        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.numberOfLines = 1
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 24),

            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            labelLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            labelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}