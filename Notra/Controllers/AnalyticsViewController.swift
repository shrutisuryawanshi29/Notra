//
//  AnalyticsViewController.swift
//  Notra
//

import UIKit

class AnalyticsViewController: UIViewController {

    private let viewModel: AnalyticsViewModel

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = AppTheme.Colors.background
        return sv
    }()
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.distribution = .fill
        stack.backgroundColor = AppTheme.Colors.background
        return stack
    }()

    private let emptyStateView = EmptyStateView()

    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = AppTheme.Colors.primaryBrown
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "Crunching the numbers…"
        label.font = AppTheme.Fonts.body
        label.textColor = AppTheme.Colors.textMuted
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        return view
    }()

    private let errorView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        let iconView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        iconView.tintColor = AppTheme.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "Couldn't load analytics. Try refreshing."
        label.font = AppTheme.Fonts.body
        label.textColor = AppTheme.Colors.textMuted
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -24),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        return view
    }()
    private let headerView = UIView()
    private let viewModeSegmentedControl: UISegmentedControl = {
        let items = AnalyticsViewMode.allCases.map { $0.title }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        return control
    }()
    private let monthSelectorButton = UIButton(type: .system)
    private let timeRangeSegmentedControl: UISegmentedControl = {
        let items = AnalyticsTimeRange.allCases.map { $0.title }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        return control
    }()

    private let monthlyComparisonSectionLabel = UILabel()
    private let monthlyComparisonStackView = UIStackView()

    private let incomeVsExpenseOverTimeSectionLabel = UILabel()
    private let incomeVsExpenseOverTimeStackView = UIStackView()

    private let categoryTrendSectionLabel = UILabel()
    private let categoryTrendStackView = UIStackView()

    private let categoryBreakdownSectionLabel = UILabel()
    private let categoryBreakdownStackView = UIStackView()

    private let dailySpendingDetailSectionLabel = UILabel()
    private let dailySpendingDetailStackView = UIStackView()

    private let incomeSourceDetailSectionLabel = UILabel()
    private let incomeSourceDetailStackView = UIStackView()

    private let summaryContainer = UIView()
    private let expenseColumn = UIView()
    private let incomeColumn = UIView()
    private let netColumn = UIView()
    
    private let expenseIcon = UIImageView()
    private let expenseTitleLabel = UILabel()
    private let expenseValueLabel = UILabel()
    private let expenseSubtitleLabel = UILabel()
    
    private let incomeIcon = UIImageView()
    private let incomeTitleLabel = UILabel()
    private let incomeValueLabel = UILabel()
    private let incomeSubtitleLabel = UILabel()
    
    private let netIcon = UIImageView()
    private let netTitleLabel = UILabel()
    private let netValueLabel = UILabel()
    private let netSubtitleLabel = UILabel()

    private let expenseSectionLabel = UILabel()
    private let expenseStackView = UIStackView()

    private let dailySpendingSectionLabel = UILabel()
    private let dailySpendingStackView = UIStackView()

    private let incomeVsExpenseSectionLabel = UILabel()
    private let incomeVsExpenseStackView = UIStackView()

    private let incomeSectionLabel = UILabel()
    private let incomeStackView = UIStackView()

    private let monthlyTrendSectionLabel = UILabel()
    private let monthlyTrendStackView = UIStackView()

    private let insightsSectionLabel = UILabel()
    private let insightsStackView = UIStackView()

    init(month: MonthMetadata? = nil) {
        self.viewModel = AnalyticsViewModel(month: month)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addSeparatorsIfNeeded()
    }
    
    private var separatorsAdded = false
    private func addSeparatorsIfNeeded() {
        guard !separatorsAdded, summaryContainer.bounds.width > 0 else { return }
        separatorsAdded = true
        
        let sep1 = UIView()
        sep1.backgroundColor = AppTheme.Colors.border
        summaryContainer.addSubview(sep1)
        
        let sep2 = UIView()
        sep2.backgroundColor = AppTheme.Colors.border
        summaryContainer.addSubview(sep2)
        
        let third = summaryContainer.bounds.width / 3
        
        sep1.frame = CGRect(x: third - 0.5, y: 0, width: 1, height: summaryContainer.bounds.height)
        sep2.frame = CGRect(x: (third * 2) - 0.5, y: 0, width: 1, height: summaryContainer.bounds.height)
    }

    private func setupUI() {
        title = "Analytics"
        view.backgroundColor = AppTheme.Colors.background

        navigationController?.navigationBar.prefersLargeTitles = false
        if let navBar = navigationController?.navigationBar {
            AppTheme.styleNavigationBar(navBar)
        }

        setupScrollView()
        setupLoadingView()
        setupErrorView()
        setupEmptyState()
        setupHeader()
        setupSummaryCards()
        setupExpenseSection()
        setupCategoryBreakdownSection()
        setupDailySpendingSection()
        setupDailySpendingDetailSection()
        setupIncomeVsExpenseSection()
        setupIncomeSection()
        setupIncomeSourceDetailSection()
        setupMonthlyTrendSection()
        setupMonthlyComparisonSection()
        setupIncomeVsExpenseOverTimeSection()
        setupCategoryTrendSection()
        setupInsightsSection()

        setupCustomSpacing()
    }

    private func setupCustomSpacing() {
        contentStackView.setCustomSpacing(12, after: headerView)
        contentStackView.setCustomSpacing(16, after: expenseSectionLabel)
        contentStackView.setCustomSpacing(12, after: expenseStackView)
        contentStackView.setCustomSpacing(16, after: categoryBreakdownSectionLabel)
        contentStackView.setCustomSpacing(32, after: categoryBreakdownStackView)
        contentStackView.setCustomSpacing(16, after: dailySpendingSectionLabel)
        contentStackView.setCustomSpacing(12, after: dailySpendingStackView)
        contentStackView.setCustomSpacing(16, after: dailySpendingDetailSectionLabel)
        contentStackView.setCustomSpacing(32, after: dailySpendingDetailStackView)
        contentStackView.setCustomSpacing(16, after: incomeVsExpenseSectionLabel)
        contentStackView.setCustomSpacing(32, after: incomeVsExpenseStackView)
        contentStackView.setCustomSpacing(16, after: incomeSectionLabel)
        contentStackView.setCustomSpacing(12, after: incomeStackView)
        contentStackView.setCustomSpacing(16, after: incomeSourceDetailSectionLabel)
        contentStackView.setCustomSpacing(32, after: incomeSourceDetailStackView)
        contentStackView.setCustomSpacing(16, after: monthlyTrendSectionLabel)
        contentStackView.setCustomSpacing(32, after: monthlyTrendStackView)
        contentStackView.setCustomSpacing(16, after: monthlyComparisonSectionLabel)
        contentStackView.setCustomSpacing(32, after: monthlyComparisonStackView)
        contentStackView.setCustomSpacing(16, after: incomeVsExpenseOverTimeSectionLabel)
        contentStackView.setCustomSpacing(32, after: incomeVsExpenseOverTimeStackView)
        contentStackView.setCustomSpacing(16, after: categoryTrendSectionLabel)
        contentStackView.setCustomSpacing(32, after: categoryTrendStackView)
        contentStackView.setCustomSpacing(16, after: insightsSectionLabel)
        contentStackView.setCustomSpacing(32, after: insightsStackView)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)            

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        emptyStateView.configure(
            icon: "chart.bar.xaxis",
            title: "No analytics yet",
            message: "Add a transaction to get started."
        )

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func setupLoadingView() {
        loadingView.isHidden = true
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupErrorView() {
        errorView.isHidden = true
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(headerView)

        viewModeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeSegmentedControl.addTarget(self, action: #selector(viewModeChanged), for: .valueChanged)
        styleSegmentedControl(viewModeSegmentedControl)
        headerView.addSubview(viewModeSegmentedControl)

        monthSelectorButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        monthSelectorButton.semanticContentAttribute = .forceRightToLeft
        monthSelectorButton.titleLabel?.font = AppTheme.Fonts.bodyMedium
        monthSelectorButton.setTitleColor(AppTheme.Colors.primaryBrown, for: .normal)
        monthSelectorButton.tintColor = AppTheme.Colors.primaryBrown
        monthSelectorButton.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        monthSelectorButton.layer.cornerRadius = AppTheme.CornerRadius.pill
        monthSelectorButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        monthSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        monthSelectorButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
        headerView.addSubview(monthSelectorButton)

        updateMonthButton()

        timeRangeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        timeRangeSegmentedControl.addTarget(self, action: #selector(timeRangeChanged), for: .valueChanged)
        styleSegmentedControl(timeRangeSegmentedControl)
        headerView.addSubview(timeRangeSegmentedControl)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),

            viewModeSegmentedControl.topAnchor.constraint(equalTo: headerView.topAnchor),
            viewModeSegmentedControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            viewModeSegmentedControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            viewModeSegmentedControl.heightAnchor.constraint(equalToConstant: 36),

            monthSelectorButton.topAnchor.constraint(equalTo: viewModeSegmentedControl.bottomAnchor, constant: 12),
            monthSelectorButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            timeRangeSegmentedControl.topAnchor.constraint(equalTo: monthSelectorButton.bottomAnchor, constant: 12),
            timeRangeSegmentedControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            timeRangeSegmentedControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            timeRangeSegmentedControl.heightAnchor.constraint(equalToConstant: 36),
            timeRangeSegmentedControl.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }

    @objc private func timeRangeChanged() {
        guard let range = AnalyticsTimeRange(rawValue: timeRangeSegmentedControl.selectedSegmentIndex) else { return }
        viewModel.setTimeRange(range)
        updateUI()
    }

    private func setupMonthlyComparisonSection() {
        monthlyComparisonSectionLabel.text = "Monthly Expense Comparison"
        monthlyComparisonSectionLabel.font = AppTheme.Fonts.sectionHeader
        monthlyComparisonSectionLabel.textColor = AppTheme.Colors.textPrimary
        monthlyComparisonSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(monthlyComparisonSectionLabel)

        monthlyComparisonStackView.axis = .vertical
        monthlyComparisonStackView.spacing = 12
        monthlyComparisonStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(monthlyComparisonStackView)

        NSLayoutConstraint.activate([
            monthlyComparisonSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            monthlyComparisonSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            monthlyComparisonStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            monthlyComparisonStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            monthlyComparisonStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func setupIncomeVsExpenseOverTimeSection() {
        incomeVsExpenseOverTimeSectionLabel.text = "Income vs Expenses Over Time"
        incomeVsExpenseOverTimeSectionLabel.font = AppTheme.Fonts.sectionHeader
        incomeVsExpenseOverTimeSectionLabel.textColor = AppTheme.Colors.textPrimary
        incomeVsExpenseOverTimeSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeVsExpenseOverTimeSectionLabel)

        incomeVsExpenseOverTimeStackView.axis = .vertical
        incomeVsExpenseOverTimeStackView.spacing = 12
        incomeVsExpenseOverTimeStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeVsExpenseOverTimeStackView)

        NSLayoutConstraint.activate([
            incomeVsExpenseOverTimeSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeVsExpenseOverTimeSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            incomeVsExpenseOverTimeStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeVsExpenseOverTimeStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            incomeVsExpenseOverTimeStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func setupCategoryTrendSection() {
        categoryTrendSectionLabel.text = "Category Trends"
        categoryTrendSectionLabel.font = AppTheme.Fonts.sectionHeader
        categoryTrendSectionLabel.textColor = AppTheme.Colors.textPrimary
        categoryTrendSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(categoryTrendSectionLabel)

        categoryTrendStackView.axis = .vertical
        categoryTrendStackView.spacing = 12
        categoryTrendStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(categoryTrendStackView)

        NSLayoutConstraint.activate([
            categoryTrendSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            categoryTrendSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            categoryTrendStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            categoryTrendStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            categoryTrendStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func styleSegmentedControl(_ control: UISegmentedControl) {
        control.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        control.selectedSegmentTintColor = AppTheme.currentMode == .dark ? AppTheme.Colors.accent : AppTheme.Colors.primaryBrown

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: AppTheme.Colors.textPrimary,
            .font: AppTheme.Fonts.captionMedium
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: AppTheme.currentMode == .dark ? AppTheme.Colors.textPrimary : UIColor.white,
            .font: AppTheme.Fonts.captionMedium
        ]

        control.setTitleTextAttributes(normalAttributes, for: .normal)
        control.setTitleTextAttributes(selectedAttributes, for: .selected)
    }

    @objc private func viewModeChanged() {
        guard let mode = AnalyticsViewMode(rawValue: viewModeSegmentedControl.selectedSegmentIndex) else { return }
        viewModel.setViewMode(mode)
        updateUI()
    }

    private func updateMonthButton() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.year = viewModel.selectedMonth.year
        components.month = viewModel.selectedMonth.month
        components.day = 1
        let displayDate = Calendar.current.date(from: components) ?? Date()
        monthSelectorButton.setTitle(" \(formatter.string(from: displayDate)) ", for: .normal)
    }

    @objc private func monthSelectorTapped() {
        let alert = UIAlertController(title: "Select Month", message: nil, preferredStyle: .actionSheet)

        for month in availableMonths {
            let monthName = getMonthDisplayString(for: month)
            alert.addAction(UIAlertAction(title: monthName, style: .default) { [weak self] _ in
                self?.viewModel.selectedMonth = month
                self?.loadData()
                self?.updateMonthButton()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = monthSelectorButton
            popover.sourceRect = monthSelectorButton.bounds
        }

        present(alert, animated: true)
    }

    private var availableMonths: [MonthMetadata] {
        let cachedMonths = SessionCacheManager.shared.getFetchedMonths()
        if cachedMonths.isEmpty {
            return [MonthMetadata(date: Date())]
        }
        return cachedMonths.sorted { $0.monthKey > $1.monthKey }
    }

    private func getMonthDisplayString(for month: MonthMetadata) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.year = month.year
        components.month = month.month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return month.monthKey
    }

    private func setupSummaryCards() {
        summaryContainer.backgroundColor = AppTheme.Colors.cardBackground
        summaryContainer.layer.cornerRadius = 12
        summaryContainer.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(summaryContainer)

        let expenseStack = createSummaryStack(icon: "arrow.up.circle.fill", color: AppTheme.Colors.expense, title: "Expenses")
        expenseStack.tag = 101

        let incomeStack = createSummaryStack(icon: "arrow.down.circle.fill", color: AppTheme.Colors.income, title: "Income")
        incomeStack.tag = 102

        let netStack = createSummaryStack(icon: "wallet.pass.fill", color: AppTheme.Colors.accent, title: "Net")
        netStack.tag = 103

        let mainStack = UIStackView(arrangedSubviews: [expenseStack, incomeStack, netStack])
        mainStack.axis = .horizontal
        mainStack.distribution = .fillEqually
        mainStack.spacing = 0
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        summaryContainer.addSubview(mainStack)

        NSLayoutConstraint.activate([
            summaryContainer.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            summaryContainer.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            summaryContainer.heightAnchor.constraint(equalToConstant: 100),

            mainStack.topAnchor.constraint(equalTo: summaryContainer.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor)
        ])
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = AppTheme.Colors.border
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }
    
    private func createSummaryStack(icon: String, color: UIColor, title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.Fonts.caption
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let valueLabel = UILabel()
        valueLabel.text = "$0.00"
        valueLabel.font = AppTheme.Fonts.bodyBold
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.tag = 200
        container.addSubview(valueLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "0"
        subtitleLabel.font = AppTheme.Fonts.small
        subtitleLabel.textColor = AppTheme.Colors.textMuted
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func setupColumn(_ container: UIView, icon: UIImageView, titleLabel: UILabel, valueLabel: UILabel, subtitleLabel: UILabel, iconName: String, title: String, color: UIColor, defaultValue: String, defaultSubtitle: String) {
        icon.image = UIImage(systemName: iconName)
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tag = 100
        container.addSubview(icon)
        
        titleLabel.text = title
        titleLabel.font = AppTheme.Fonts.caption
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        valueLabel.text = defaultValue
        valueLabel.font = AppTheme.Fonts.bodyBold
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.numberOfLines = 1
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        subtitleLabel.text = defaultSubtitle
        subtitleLabel.font = AppTheme.Fonts.small
        subtitleLabel.textColor = AppTheme.Colors.textMuted
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            
            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
            
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -8)
        ])
    }

    private func setupExpenseSection() {
        expenseSectionLabel.text = "Expense Categories"
        expenseSectionLabel.font = AppTheme.Fonts.sectionHeader
        expenseSectionLabel.textColor = AppTheme.Colors.textPrimary
        expenseSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(expenseSectionLabel)

        expenseStackView.axis = .vertical
        expenseStackView.spacing = 16
        expenseStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(expenseStackView)

        NSLayoutConstraint.activate([
            expenseSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            expenseSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            expenseStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            expenseStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func setupDailySpendingSection() {
        dailySpendingSectionLabel.text = "Daily Spending"
        dailySpendingSectionLabel.font = AppTheme.Fonts.sectionHeader
        dailySpendingSectionLabel.textColor = AppTheme.Colors.textPrimary
        dailySpendingSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(dailySpendingSectionLabel)

        dailySpendingStackView.axis = .vertical
        dailySpendingStackView.spacing = 16
        dailySpendingStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(dailySpendingStackView)

        NSLayoutConstraint.activate([
            dailySpendingSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            dailySpendingSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            dailySpendingStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            dailySpendingStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            dailySpendingStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func setupIncomeVsExpenseSection() {
        incomeVsExpenseSectionLabel.text = ""
        incomeVsExpenseSectionLabel.font = AppTheme.Fonts.sectionHeader
        incomeVsExpenseSectionLabel.textColor = AppTheme.Colors.textPrimary
        incomeVsExpenseSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeVsExpenseSectionLabel)

        incomeVsExpenseStackView.axis = .vertical
        incomeVsExpenseStackView.spacing = 12
        incomeVsExpenseStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeVsExpenseStackView)

        NSLayoutConstraint.activate([
            incomeVsExpenseSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeVsExpenseSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            incomeVsExpenseStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeVsExpenseStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            incomeVsExpenseStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func setupIncomeSection() {
        incomeSectionLabel.text = "Income Sources"
        incomeSectionLabel.font = AppTheme.Fonts.sectionHeader
        incomeSectionLabel.textColor = AppTheme.Colors.textPrimary
        incomeSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeSectionLabel)

        incomeStackView.axis = .vertical
        incomeStackView.spacing = 16
        incomeStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeStackView)

        NSLayoutConstraint.activate([
            incomeSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            incomeStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func setupMonthlyTrendSection() {
        monthlyTrendSectionLabel.text = ""
        monthlyTrendSectionLabel.font = AppTheme.Fonts.sectionHeader
        monthlyTrendSectionLabel.textColor = AppTheme.Colors.textPrimary
        monthlyTrendSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(monthlyTrendSectionLabel)

        monthlyTrendStackView.axis = .vertical
        monthlyTrendStackView.spacing = 12
        monthlyTrendStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(monthlyTrendStackView)

        NSLayoutConstraint.activate([
            monthlyTrendSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            monthlyTrendSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            monthlyTrendStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            monthlyTrendStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            monthlyTrendStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func setupInsightsSection() {
        insightsSectionLabel.text = "Insights"
        insightsSectionLabel.font = AppTheme.Fonts.sectionHeader
        insightsSectionLabel.textColor = AppTheme.Colors.textPrimary
        insightsSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(insightsSectionLabel)

        insightsStackView.axis = .vertical
        insightsStackView.spacing = 12
        insightsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(insightsStackView)

        NSLayoutConstraint.activate([
            insightsSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            insightsSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            insightsStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            insightsStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func setupCategoryBreakdownSection() {
        categoryBreakdownSectionLabel.text = "Category Breakdown"
        categoryBreakdownSectionLabel.font = AppTheme.Fonts.sectionHeader
        categoryBreakdownSectionLabel.textColor = AppTheme.Colors.textPrimary
        categoryBreakdownSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(categoryBreakdownSectionLabel)

        categoryBreakdownStackView.axis = .vertical
        categoryBreakdownStackView.spacing = 8
        categoryBreakdownStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(categoryBreakdownStackView)

        NSLayoutConstraint.activate([
            categoryBreakdownSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            categoryBreakdownSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            categoryBreakdownStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            categoryBreakdownStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func setupDailySpendingDetailSection() {
        dailySpendingDetailSectionLabel.text = "Spending Details"
        dailySpendingDetailSectionLabel.font = AppTheme.Fonts.sectionHeader
        dailySpendingDetailSectionLabel.textColor = AppTheme.Colors.textPrimary
        dailySpendingDetailSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(dailySpendingDetailSectionLabel)

        dailySpendingDetailStackView.axis = .vertical
        dailySpendingDetailStackView.spacing = 12
        dailySpendingDetailStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(dailySpendingDetailStackView)

        NSLayoutConstraint.activate([
            dailySpendingDetailSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            dailySpendingDetailSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            dailySpendingDetailStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            dailySpendingDetailStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func setupIncomeSourceDetailSection() {
        incomeSourceDetailSectionLabel.text = "Income Sources"
        incomeSourceDetailSectionLabel.font = AppTheme.Fonts.sectionHeader
        incomeSourceDetailSectionLabel.textColor = AppTheme.Colors.textPrimary
        incomeSourceDetailSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeSourceDetailSectionLabel)

        incomeSourceDetailStackView.axis = .vertical
        incomeSourceDetailStackView.spacing = 8
        incomeSourceDetailStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(incomeSourceDetailStackView)

        NSLayoutConstraint.activate([
            incomeSourceDetailSectionLabel.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeSourceDetailSectionLabel.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            incomeSourceDetailStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            incomeSourceDetailStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20)
        ])
    }

    private func loadData() {
        loadingView.isHidden = false
        scrollView.isHidden = true
        emptyStateView.isHidden = true
        errorView.isHidden = true

        viewModel.loadAnalytics()

        if viewModel.isLoading {
            return
        }

        if viewModel.hasError {
            loadingView.isHidden = true
            errorView.isHidden = false
            return
        }

        loadingView.isHidden = true

        if viewModel.hasData {
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            updateUI()
        } else if viewModel.expenseTransactionCount == 0 && viewModel.incomeTransactionCount == 0 {
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(
                icon: "chart.bar.xaxis",
                title: "No analytics yet",
                message: "Add a transaction to get started."
            )
        } else {
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            updateUI()
        }
    }

    private func updateUI() {
        updateSummaryCards()
        updateSectionsForViewMode()
        view.layoutIfNeeded()
    }

    private func updateSummaryCards() {
        guard let mainStack = summaryContainer.subviews.first as? UIStackView else { return }

        if mainStack.arrangedSubviews.count >= 3 {
            if let expenseContainer = mainStack.arrangedSubviews[0].viewWithTag(200) as? UILabel {
                expenseContainer.text = viewModel.formattedTotalExpenses
            }
            if let expenseSubtitle = mainStack.arrangedSubviews[0].subviews.last as? UILabel {
                expenseSubtitle.text = "\(viewModel.expenseTransactionCount)"
            }

            if let incomeContainer = mainStack.arrangedSubviews[1].viewWithTag(200) as? UILabel {
                incomeContainer.text = viewModel.formattedTotalIncomes
            }
            if let incomeSubtitle = mainStack.arrangedSubviews[1].subviews.last as? UILabel {
                incomeSubtitle.text = "\(viewModel.incomeTransactionCount)"
            }

            let netLabel = viewModel.netBalance >= 0 ? "Saved" : "Over"
            let netColor: UIColor = viewModel.netBalance >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense
            if let netContainer = mainStack.arrangedSubviews[2].viewWithTag(200) as? UILabel {
                netContainer.text = viewModel.formattedNetBalance
                netContainer.textColor = netColor
            }
            if let netSubtitle = mainStack.arrangedSubviews[2].subviews.last as? UILabel {
                netSubtitle.text = netLabel
            }
        }
    }

    private func updateSectionsForViewMode() {
        let mode = viewModel.viewMode

        timeRangeSegmentedControl.isHidden = !shouldShowTimeRange(for: mode)

        summaryContainer.isHidden = mode != .overview
        expenseSectionLabel.isHidden = !showExpenseSection(for: mode)
        expenseStackView.isHidden = !showExpenseSection(for: mode)
        categoryBreakdownSectionLabel.isHidden = mode != .expenses || viewModel.expenseCategories.isEmpty
        categoryBreakdownStackView.isHidden = mode != .expenses || viewModel.expenseCategories.isEmpty
        dailySpendingSectionLabel.isHidden = !showDailySpendingSection(for: mode)
        dailySpendingStackView.isHidden = !showDailySpendingSection(for: mode)
        dailySpendingDetailSectionLabel.isHidden = mode != .expenses || viewModel.dailySpendingStats == nil
        dailySpendingDetailStackView.isHidden = mode != .expenses || viewModel.dailySpendingStats == nil
        incomeVsExpenseSectionLabel.isHidden = !showIncomeVsExpenseSection(for: mode)
        incomeVsExpenseStackView.isHidden = !showIncomeVsExpenseSection(for: mode)
        incomeSectionLabel.isHidden = !showIncomeSection(for: mode)
        incomeStackView.isHidden = !showIncomeSection(for: mode)
        incomeSourceDetailSectionLabel.isHidden = mode != .income || viewModel.incomeCategories.isEmpty
        incomeSourceDetailStackView.isHidden = mode != .income || viewModel.incomeCategories.isEmpty
        monthlyTrendSectionLabel.isHidden = mode != .trends
        monthlyTrendStackView.isHidden = mode != .trends
        monthlyComparisonSectionLabel.isHidden = !showMonthlyComparisonSection(for: mode)
        monthlyComparisonStackView.isHidden = !showMonthlyComparisonSection(for: mode)
        incomeVsExpenseOverTimeSectionLabel.isHidden = !showIncomeVsExpenseOverTimeSection(for: mode)
        incomeVsExpenseOverTimeStackView.isHidden = !showIncomeVsExpenseOverTimeSection(for: mode)
        categoryTrendSectionLabel.isHidden = !showCategoryTrendSection(for: mode)
        categoryTrendStackView.isHidden = !showCategoryTrendSection(for: mode)
        insightsSectionLabel.isHidden = mode != .overview
        insightsStackView.isHidden = mode != .overview

        updateExpenseSection()
        updateCategoryBreakdownSection()
        updateDailySpendingSection()
        updateDailySpendingDetailSection()
        updateIncomeVsExpenseSection()
        updateIncomeSection()
        updateIncomeSourceDetailSection()
        updateMonthlyTrendSection()
        updateMonthlyComparisonSection()
        updateIncomeVsExpenseOverTimeSection()
        updateCategoryTrendSection()
        updateInsightsSection()
    }

    private func shouldShowTimeRange(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .trends:
            return true
        case .expenses:
            return viewModel.hasMultipleMonths
        case .income:
            return viewModel.hasMultipleMonths
        }
    }

    private func showMonthlyComparisonSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .trends, .expenses:
            return true
        case .income:
            return false
        }
    }

    private func showIncomeVsExpenseOverTimeSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .trends, .income:
            return true
        case .expenses:
            return false
        }
    }

    private func showCategoryTrendSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .trends, .expenses:
            return true
        case .income:
            return false
        }
    }

    private func showExpenseSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .expenses:
            return true
        case .income, .trends:
            return false
        }
    }

    private func showDailySpendingSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .expenses, .trends:
            return viewModel.hasDailySpending || mode == .overview
        case .income:
            return false
        }
    }

    private func showIncomeVsExpenseSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .income:
            return true
        case .expenses, .trends:
            return false
        }
    }

    private func showIncomeSection(for mode: AnalyticsViewMode) -> Bool {
        switch mode {
        case .overview, .income:
            return true
        case .expenses, .trends:
            return false
        }
    }

    private func updateExpenseSection() {
        expenseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.expenseCategories.isEmpty {
            addEmptyState(to: expenseStackView, message: viewModel.viewMode == .expenses ? "No expenses found for this month." : "No expense data")
        } else {
            let cardView = createChartCardView(title: "Expense Categories")
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.expenseCategories, totalAmount: viewModel.totalExpenses, color: AppTheme.Colors.expense)
            cardView.addSubview(donutChart)
            donutChart.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                donutChart.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
                donutChart.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
                donutChart.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
                donutChart.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
            ])
            expenseStackView.addArrangedSubview(cardView)

            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

            if viewModel.viewMode == .expenses || viewModel.viewMode == .overview {
                let actionButton = createCardActionButton(title: "View Expenses", icon: "list.bullet")
                actionButton.addTarget(self, action: #selector(viewExpensesTapped), for: .touchUpInside)
                expenseStackView.addArrangedSubview(actionButton)
            }
        }
    }

    private func updateCategoryBreakdownSection() {
        categoryBreakdownStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let categories = viewModel.topExpenseCategories(limit: 5)
        for (index, category) in categories.enumerated() {
            let detailView = createCategoryDetailRow(category: category, color: chartColorForIndex(index))
            categoryBreakdownStackView.addArrangedSubview(detailView)
        }
    }

    private func updateDailySpendingSection() {
        dailySpendingStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.hasDailySpending {
            let cardView = createChartCardView(title: "Daily Spending")
            let dailyChart = DailySpendingChartView()
            dailyChart.configure(with: viewModel.dailySpendingData, spendingDaysCount: viewModel.spendingDaysCount)
            cardView.addSubview(dailyChart)
            dailyChart.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dailyChart.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 60),
                dailyChart.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
                dailyChart.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
                dailyChart.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
            ])
            dailySpendingStackView.addArrangedSubview(cardView)

            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

            if viewModel.viewMode == .expenses || viewModel.viewMode == .trends {
                let actionButton = createCardActionButton(title: "View Transactions", icon: "doc.text")
                actionButton.addTarget(self, action: #selector(viewTransactionsTapped), for: .touchUpInside)
                dailySpendingStackView.addArrangedSubview(actionButton)
            }
        } else if viewModel.viewMode != .income {
            addEmptyState(to: dailySpendingStackView, message: "No expenses for this month yet.")
        }
    }

    private func updateDailySpendingDetailSection() {
        dailySpendingDetailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let stats = viewModel.dailySpendingStats else { return }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        addDetailRow(to: dailySpendingDetailStackView, icon: "arrow.up.circle.fill", title: "Highest day", value: "\(stats.highestDay) · \(formatter.string(from: NSNumber(value: stats.highestAmount)) ?? "$0")")
        addDetailRow(to: dailySpendingDetailStackView, icon: "chart.bar.fill", title: "Average per day", value: formatter.string(from: NSNumber(value: stats.average)) ?? "$0")
        addDetailRow(to: dailySpendingDetailStackView, icon: "calendar.badge.clock", title: "Spending days", value: "\(stats.spendingDays)")
        if let lowestDay = stats.lowestDay, stats.spendingDays > 1 {
            addDetailRow(to: dailySpendingDetailStackView, icon: "arrow.down.circle.fill", title: "Lowest day", value: "\(lowestDay) · \(formatter.string(from: NSNumber(value: stats.lowestAmount)) ?? "$0")")
        }
    }

    private func updateIncomeVsExpenseSection() {
        incomeVsExpenseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let incomeVsData = viewModel.incomeVsExpenseData {
            let comparisonChart = IncomeVsExpenseChartView()
            comparisonChart.configure(with: incomeVsData)
            incomeVsExpenseStackView.addArrangedSubview(comparisonChart)
            comparisonChart.heightAnchor.constraint(equalToConstant: 280).isActive = true
        } else {
            addEmptyState(to: incomeVsExpenseStackView, message: "No data available")
        }
    }

    private func updateIncomeSection() {
        incomeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.incomeCategories.isEmpty {
            addEmptyState(to: incomeStackView, message: viewModel.viewMode == .income ? "No income found for this month." : "No income data")
        } else {
            let cardView = createChartCardView(title: "Income Sources")
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.incomeCategories, totalAmount: viewModel.totalIncomes, color: AppTheme.Colors.income)
            cardView.addSubview(donutChart)
            donutChart.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                donutChart.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
                donutChart.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
                donutChart.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
                donutChart.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
            ])
            incomeStackView.addArrangedSubview(cardView)

            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

            if viewModel.viewMode == .income || viewModel.viewMode == .overview {
                let actionButton = createCardActionButton(title: "View Income", icon: "list.bullet")
                actionButton.addTarget(self, action: #selector(viewIncomeTapped), for: .touchUpInside)
                incomeStackView.addArrangedSubview(actionButton)
            }
        }
    }

    private func updateIncomeSourceDetailSection() {
        incomeSourceDetailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let sources = viewModel.topIncomeSources(limit: 5)
        for (index, source) in sources.enumerated() {
            let detailView = createIncomeSourceDetailRow(source: source, color: incomeChartColorForIndex(index))
            incomeSourceDetailStackView.addArrangedSubview(detailView)
        }
    }

    private func updateMonthlyTrendSection() {
        monthlyTrendStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.canShowTrend {
            let trendChart = MonthlyTrendChartView()
            trendChart.configure(with: viewModel.monthlyTrendData)
            monthlyTrendStackView.addArrangedSubview(trendChart)
            trendChart.heightAnchor.constraint(equalToConstant: 300).isActive = true
        } else {
            addEmptyState(to: monthlyTrendStackView, message: "Load another month to compare trends.")
        }
    }

    private func updateMonthlyComparisonSection() {
        monthlyComparisonStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let data = viewModel.monthlyExpenseComparisonData.filter { $0.totalExpenses > 0 }
        let emptyMsg = viewModel.missingMonthsMessage() ?? "Load more months to compare spending."

        if data.count > 1 {
            let chart = MonthlyComparisonChartView()
            chart.configure(with: viewModel.monthlyExpenseComparisonData, emptyMessage: emptyMsg)
            monthlyComparisonStackView.addArrangedSubview(chart)
            chart.heightAnchor.constraint(equalToConstant: 320).isActive = true
        } else if viewModel.timeRange != .thisMonth {
            addEmptyState(to: monthlyComparisonStackView, message: emptyMsg)
        }
    }

    private func updateIncomeVsExpenseOverTimeSection() {
        incomeVsExpenseOverTimeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let data = viewModel.incomeVsExpenseOverTimeData.filter { $0.totalExpenses > 0 || $0.totalIncome > 0 }
        let emptyMsg = viewModel.missingMonthsMessage() ?? "Load another month to compare income and expenses."

        if data.count > 1 {
            let chart = IncomeVsExpenseMultiMonthChartView()
            chart.configure(with: viewModel.incomeVsExpenseOverTimeData, emptyMessage: emptyMsg)
            incomeVsExpenseOverTimeStackView.addArrangedSubview(chart)
            chart.heightAnchor.constraint(equalToConstant: 320).isActive = true
        } else if viewModel.timeRange != .thisMonth {
            addEmptyState(to: incomeVsExpenseOverTimeStackView, message: emptyMsg)
        }
    }

    private func updateCategoryTrendSection() {
        categoryTrendStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let emptyMsg = viewModel.missingMonthsMessage() ?? "Load more months to view category trends."

        if viewModel.hasMultipleMonths && !viewModel.topTrendCategories.isEmpty {
            let chart = CategoryTrendChartView()
            chart.configure(with: viewModel.categoryTrendData, topCategories: viewModel.topTrendCategories, emptyMessage: emptyMsg)
            categoryTrendStackView.addArrangedSubview(chart)
            chart.heightAnchor.constraint(equalToConstant: 340).isActive = true
        } else if viewModel.timeRange != .thisMonth {
            addEmptyState(to: categoryTrendStackView, message: emptyMsg)
        }
    }

    private func updateInsightsSection() {
        insightsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let topCategory = viewModel.topSpendingCategory {
            addInsightRow(icon: "arrow.up.circle.fill", title: "Your highest category this month", value: topCategory, color: AppTheme.Colors.expense)
        }

        if let highestDay = viewModel.highestSpendingDay {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let amountStr = formatter.string(from: NSNumber(value: viewModel.highestSpendingDayAmount)) ?? "$0"
            addInsightRow(icon: "calendar", title: "The day with the most expenses", value: "\(highestDay) (\(amountStr))", color: AppTheme.Colors.accent)
        }

        addInsightRow(icon: "list.bullet", title: "Transactions tracked this month", value: "\(viewModel.expenseTransactionCount) transactions", color: AppTheme.Colors.expense)
        addInsightRow(icon: "plus.circle.fill", title: "Income entries tracked this month", value: "\(viewModel.incomeTransactionCount) transactions", color: AppTheme.Colors.income)
    }

    private func createChartCardView(title: String) -> UIView {
        let card = UIView()
        AppTheme.applyCardStyle(to: card)
        card.backgroundColor = AppTheme.Colors.cardBackground
        card.layer.cornerRadius = AppTheme.CornerRadius.card
        return card
    }

    private func createCardActionButton(title: String, icon: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("  \(title)", for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.titleLabel?.font = AppTheme.Fonts.captionMedium
        button.setTitleColor(AppTheme.Colors.primaryBrown, for: .normal)
        button.tintColor = AppTheme.Colors.primaryBrown
        button.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        button.layer.cornerRadius = AppTheme.CornerRadius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    private func createCategoryDetailRow(category: CategoryBreakdown, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.Colors.cardBackground
        container.layer.cornerRadius = AppTheme.CornerRadius.medium

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 5
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorDot)

        let nameLabel = UILabel()
        nameLabel.text = category.category
        nameLabel.font = AppTheme.Fonts.bodyMedium
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let detailLabel = UILabel()
        detailLabel.text = "\(category.formattedAmount) · \(category.formattedPercentage) · \(category.transactionCount) transactions"
        detailLabel.font = AppTheme.Fonts.caption
        detailLabel.textColor = AppTheme.Colors.textSecondary
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),

            colorDot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            colorDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 10),
            colorDot.heightAnchor.constraint(equalToConstant: 10),

            nameLabel.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),

            detailLabel.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 12),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }

    private func createIncomeSourceDetailRow(source: CategoryBreakdown, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.Colors.cardBackground
        container.layer.cornerRadius = AppTheme.CornerRadius.medium

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 5
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorDot)

        let nameLabel = UILabel()
        nameLabel.text = source.category
        nameLabel.font = AppTheme.Fonts.bodyMedium
        nameLabel.textColor = AppTheme.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let detailLabel = UILabel()
        detailLabel.text = "\(source.formattedAmount) · \(source.formattedPercentage) · \(source.transactionCount) transactions"
        detailLabel.font = AppTheme.Fonts.caption
        detailLabel.textColor = AppTheme.Colors.textSecondary
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),

            colorDot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            colorDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 10),
            colorDot.heightAnchor.constraint(equalToConstant: 10),

            nameLabel.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),

            detailLabel.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 12),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }

    private func addDetailRow(to stackView: UIStackView, icon: String, title: String, value: String) {
        let container = UIView()
        container.backgroundColor = AppTheme.Colors.cardBackground
        container.layer.cornerRadius = AppTheme.CornerRadius.medium

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppTheme.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.Fonts.caption
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.Fonts.bodyMedium
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        stackView.addArrangedSubview(container)
    }

    private func addEmptyState(to stackView: UIStackView, message: String) {
        let container = UIView()
        container.backgroundColor = AppTheme.Colors.cardBackground
        container.layer.cornerRadius = AppTheme.CornerRadius.card

        let iconView = UIImageView(image: UIImage(systemName: "chart.bar.xaxis"))
        iconView.tintColor = AppTheme.Colors.textMuted
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        let label = UILabel()
        label.text = message
        label.font = AppTheme.Fonts.caption
        label.textColor = AppTheme.Colors.textMuted
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 100),

            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])

        stackView.addArrangedSubview(container)
    }

    private func chartColorForIndex(_ index: Int) -> UIColor {
        let colors: [UIColor] = [
            AppTheme.Colors.expense,
            AppTheme.Colors.expenseLight,
            AppTheme.Colors.secondaryBrown,
            AppTheme.Colors.secondaryTan,
            AppTheme.Colors.accent
        ]
        return colors[index % colors.count]
    }

    private func incomeChartColorForIndex(_ index: Int) -> UIColor {
        let colors: [UIColor] = [
            AppTheme.Colors.income,
            AppTheme.Colors.incomeLight,
            AppTheme.Colors.secondaryBrown,
            AppTheme.Colors.secondaryTan,
            AppTheme.Colors.accent
        ]
        return colors[index % colors.count]
    }

    @objc private func viewExpensesTapped() {
    }

    @objc private func viewIncomeTapped() {
    }

    @objc private func viewTransactionsTapped() {
    }

    private func addInsightRow(icon: String, title: String, value: String, color: UIColor) {
        let insightView = InsightRowView()
        insightView.configure(icon: icon, title: title, value: value, color: color)
        insightsStackView.addArrangedSubview(insightView)
    }
}

class CategoryProgressBarView: UIView {
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()
    private let percentageLabel = UILabel()
    private let progressBar = UIView()
    private let progressFill = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        categoryLabel.font = AppTheme.Fonts.bodyMedium
        categoryLabel.textColor = AppTheme.Colors.textPrimary
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(categoryLabel)

        amountLabel.font = AppTheme.Fonts.caption
        amountLabel.textColor = AppTheme.Colors.textSecondary
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(amountLabel)

        percentageLabel.font = AppTheme.Fonts.captionBold
        percentageLabel.textColor = AppTheme.Colors.textSecondary
        percentageLabel.textAlignment = .right
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(percentageLabel)

        progressBar.backgroundColor = AppTheme.Colors.border
        progressBar.layer.cornerRadius = AppTheme.CornerRadius.small
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressBar)

        progressFill.layer.cornerRadius = AppTheme.CornerRadius.small
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)

        NSLayoutConstraint.activate([
            categoryLabel.topAnchor.constraint(equalTo: topAnchor),
            categoryLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            amountLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 4),
            amountLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            percentageLabel.centerYAnchor.constraint(equalTo: categoryLabel.centerYAnchor),
            percentageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            progressBar.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 8),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.heightAnchor.constraint(equalTo: progressBar.heightAnchor)
        ])
    }

    func configure(category: String, amount: String, percentage: Double, color: UIColor) {
        categoryLabel.text = category
        amountLabel.text = amount
        percentageLabel.text = String(format: "%.0f%%", percentage)
        progressFill.backgroundColor = color
        progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: CGFloat(percentage / 100)).isActive = true
    }
}

class InsightRowView: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppTheme.Colors.accent
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        titleLabel.font = AppTheme.Fonts.caption
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        valueLabel.font = AppTheme.Fonts.bodyMedium
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),

            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    func configure(icon: String, title: String, value: String, color: UIColor) {
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = color
        titleLabel.text = title
        valueLabel.text = value
    }
}

class SummaryColumnView: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 2
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.Fonts.caption
        titleLabel.textColor = AppTheme.Colors.textSecondary
        titleLabel.textAlignment = .center

        valueLabel.font = AppTheme.Fonts.headingMedium
        valueLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.numberOfLines = 1
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.font = AppTheme.Fonts.small
        subtitleLabel.textColor = AppTheme.Colors.textMuted
        subtitleLabel.textAlignment = .center

        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    func configure(icon: String, title: String, color: UIColor) {
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = color
        titleLabel.text = title
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

class DonutChartView: UIView {
    private let chartContainer = UIView()
    private let legendStackView = UIStackView()
    private var segments: [(color: UIColor, percentage: Double, label: String, amount: String)] = []
    private var centerLabel = UILabel()
    private var centerSubtitleLabel = UILabel()
    private var chartLayers: [CAShapeLayer] = []

    private let chartColors: [UIColor] = [
        AppTheme.Colors.expense, AppTheme.Colors.expenseLight, AppTheme.Colors.income, AppTheme.Colors.incomeLight,
        AppTheme.Colors.secondaryBrown, AppTheme.Colors.secondaryTan, AppTheme.Colors.accent, AppTheme.Colors.accentSecondary
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        centerLabel.font = AppTheme.Fonts.headingMedium
        centerLabel.textColor = AppTheme.Colors.textPrimary
        centerLabel.textAlignment = .center
        centerLabel.adjustsFontSizeToFitWidth = true
        centerLabel.minimumScaleFactor = 0.5
        centerLabel.numberOfLines = 1
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(centerLabel)

        centerSubtitleLabel.font = AppTheme.Fonts.small
        centerSubtitleLabel.textColor = AppTheme.Colors.textSecondary
        centerSubtitleLabel.textAlignment = .center
        centerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(centerSubtitleLabel)

        legendStackView.axis = .vertical
        legendStackView.spacing = 6
        legendStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(legendStackView)

        NSLayoutConstraint.activate([
            chartContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            chartContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            chartContainer.widthAnchor.constraint(equalToConstant: 180),
            chartContainer.heightAnchor.constraint(equalToConstant: 180),

            centerLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor, constant: -8),

            centerSubtitleLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerSubtitleLabel.topAnchor.constraint(equalTo: centerLabel.bottomAnchor, constant: 2),

            legendStackView.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 20),
            legendStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            legendStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            legendStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(with categories: [CategoryBreakdown], totalAmount: Double, color: UIColor) {
        segments = []
        legendStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chartLayers.forEach { $0.removeFromSuperlayer() }
        chartLayers.removeAll()

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        let topCategories = Array(categories.prefix(6))
        let displayTotal = formatter.string(from: NSNumber(value: totalAmount)) ?? "$0"

        centerLabel.text = displayTotal
        centerSubtitleLabel.text = "Total"

        for (index, category) in topCategories.enumerated() {
            let chartColor = chartColors[index % chartColors.count]
            segments.append((color: chartColor, percentage: category.percentage, label: category.category, amount: category.formattedAmount))

            let legendItem = createLegendItem(color: chartColor, label: category.category, amount: category.formattedAmount, percentage: category.percentage)
            legendStackView.addArrangedSubview(legendItem)
        }

        if categories.count > 6 {
            let otherTotal = categories.dropFirst(6).reduce(0) { $0 + $1.amount }
            let otherPercentage = categories.dropFirst(6).reduce(0) { $0 + $1.percentage }
            let otherFormatted = formatter.string(from: NSNumber(value: otherTotal)) ?? "$0"
            let otherColor = chartColors[min(6, chartColors.count - 1)]
            segments.append((color: otherColor, percentage: otherPercentage, label: "Other", amount: otherFormatted))
            let legendItem = createLegendItem(color: otherColor, label: "Other", amount: otherFormatted, percentage: otherPercentage)
            legendStackView.addArrangedSubview(legendItem)
        }

        DispatchQueue.main.async {
            self.drawChart()
        }
    }

    private func drawChart() {
        guard !segments.isEmpty else { return }

        let center = CGPoint(x: chartContainer.bounds.midX, y: chartContainer.bounds.midY)
        let outerRadius: CGFloat = min(chartContainer.bounds.width, chartContainer.bounds.height) / 2 - 4
        let innerRadius: CGFloat = outerRadius * 0.6

        var startAngle: CGFloat = -.pi / 2

        for segment in segments {
            let endAngle = startAngle + (2 * .pi * CGFloat(segment.percentage / 100))

            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x + innerRadius * cos(startAngle), y: center.y + innerRadius * sin(startAngle)))
            path.addArc(withCenter: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.addArc(withCenter: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: false)
            path.close()

            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.fillColor = segment.color.cgColor
            chartContainer.layer.insertSublayer(layer, at: 0)
            chartLayers.append(layer)

            startAngle = endAngle
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        chartLayers.forEach { $0.removeFromSuperlayer() }
        chartLayers.removeAll()
        if !segments.isEmpty {
            drawChart()
        }
    }

    private func createLegendItem(color: UIColor, label: String, amount: String, percentage: Double) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 5
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        colorDot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        colorDot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        row.addArrangedSubview(colorDot)

        let labelView = UILabel()
        labelView.text = label
        labelView.font = AppTheme.Fonts.captionMedium
        labelView.textColor = AppTheme.Colors.textPrimary
        labelView.adjustsFontSizeToFitWidth = true
        labelView.minimumScaleFactor = 0.8
        labelView.lineBreakMode = .byTruncatingTail
        labelView.numberOfLines = 1
        row.addArrangedSubview(labelView)

        let amountView = UILabel()
        let percentageText: String
        if percentage > 0 && percentage < 1 {
            percentageText = "<1%"
        } else {
            percentageText = "\(Int(round(percentage)))%"
        }
        amountView.text = "\(amount) (\(percentageText))"
        amountView.font = AppTheme.Fonts.small
        amountView.textColor = AppTheme.Colors.textSecondary
        amountView.setContentHuggingPriority(.required, for: .horizontal)
        amountView.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(amountView)

        return row
    }
}

class DailySpendingChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let emptyLabel = UILabel()
    private let sparseLabel = UILabel()

    private var bars: [CAShapeLayer] = []
    private var data: [DailySpendingData] = []
    private var allData: [DailySpendingData] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        emptyLabel.text = "No expenses for this month yet."
        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        sparseLabel.font = AppTheme.Fonts.small
        sparseLabel.textColor = AppTheme.Colors.textSecondary
        sparseLabel.textAlignment = .center
        sparseLabel.numberOfLines = 0
        sparseLabel.isHidden = true
        sparseLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sparseLabel)

        NSLayoutConstraint.activate([
            chartContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),

            sparseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sparseLabel.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 4),
            sparseLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sparseLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    func configure(with data: [DailySpendingData], spendingDaysCount: Int = 0) {
        self.allData = data
        self.data = data.filter { $0.amount > 0 }

        if self.data.isEmpty {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
            sparseLabel.isHidden = true
            return
        }

        chartContainer.isHidden = false
        emptyLabel.isHidden = true

        if spendingDaysCount > 0 && spendingDaysCount <= 3 {
            sparseLabel.isHidden = false
            if spendingDaysCount == 1 {
                sparseLabel.text = "Spending happened on 1 day this month."
            } else {
                sparseLabel.text = "Spending happened on \(spendingDaysCount) days this month."
            }
        } else {
            sparseLabel.isHidden = true
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawBars()
    }

private func drawBars() {
        bars.forEach { $0.removeFromSuperlayer() }
        bars.removeAll()
        chartContainer.layer.sublayers?.removeAll(where: { $0 is CATextLayer })

        guard !data.isEmpty else { return }

        let horizontalInset: CGFloat = 4
        let labelHeight: CGFloat = 16
        let availableWidth = chartContainer.bounds.width - (horizontalInset * 2)
        let availableHeight = chartContainer.bounds.height - labelHeight - 4

        let maxAmount = data.map { $0.amount }.max() ?? 1
        let barWidth: CGFloat = 6
        let slotWidth = availableWidth / CGFloat(data.count)

        let labelIndices = calculateLabelIndices(count: data.count)

        for (index, item) in data.enumerated() {
            let normalizedHeight = maxAmount > 0 ? CGFloat(item.amount / maxAmount) * (availableHeight - 8) : 0
            let barHeight = max(4, normalizedHeight)
            let centerX = horizontalInset + slotWidth * CGFloat(index) + slotWidth / 2
            let x = centerX - barWidth / 2
            let y = availableHeight - barHeight

            let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight), cornerRadius: 3)

            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.fillColor = AppTheme.Colors.expense.cgColor
            chartContainer.layer.addSublayer(layer)
            bars.append(layer)

            if labelIndices.contains(index) {
                let textLayer = CATextLayer()
                textLayer.string = "\(item.day)"
                textLayer.font = UIFont.systemFont(ofSize: 8)
                textLayer.fontSize = 8
                textLayer.foregroundColor = AppTheme.Colors.textMuted.cgColor
                textLayer.alignmentMode = .center
                textLayer.contentsScale = UIScreen.main.scale
                textLayer.frame = CGRect(x: centerX - 12, y: availableHeight + 4, width: 24, height: labelHeight)
                chartContainer.layer.addSublayer(textLayer)
            }
        }
    }

    private func calculateLabelIndices(count: Int) -> Set<Int> {
        guard count > 10 else {
            return Set(0..<count)
        }
        var indices = Set<Int>()
        let step = count / 8
        for i in stride(from: 0, to: count, by: max(step, 1)) {
            indices.insert(i)
        }
        if !indices.contains(count - 1) {
            indices.insert(count - 1)
        }
        return indices
    }
}

class IncomeVsExpenseChartView: UIView {
    private let titleLabel = UILabel()
    private let chartContainer = UIView()
    private let netLabel = UILabel()
    private let emptyLabel = UILabel()

    private var incomeBar: CAShapeLayer?
    private var expenseBar: CAShapeLayer?
    private var incomeLabelLayer: CATextLayer?
    private var expenseLabelLayer: CATextLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Income vs Expenses"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        netLabel.font = AppTheme.Fonts.bodyMedium
        netLabel.textColor = AppTheme.Colors.textSecondary
        netLabel.textAlignment = .center
        netLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(netLabel)

        emptyLabel.text = "No data available"
        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            chartContainer.heightAnchor.constraint(equalToConstant: 160),

            netLabel.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 12),
            netLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            netLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor)
        ])
    }

    func configure(with data: IncomeVsExpenseData) {
        self.data = data

        if data.totalIncome == 0 && data.totalExpenses == 0 {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
            netLabel.isHidden = true
            return
        }

        chartContainer.isHidden = false
        emptyLabel.isHidden = true
        netLabel.isHidden = false

        let netText = data.isPositive ? "Net: +\(data.formattedNet) saved" : "Net: -\(data.formattedNet) over"
        netLabel.text = netText
        netLabel.textColor = data.isPositive ? AppTheme.Colors.income : AppTheme.Colors.expense

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawBars()
    }

    private func drawBars() {
        incomeBar?.removeFromSuperlayer()
        expenseBar?.removeFromSuperlayer()
        incomeLabelLayer?.removeFromSuperlayer()
        expenseLabelLayer?.removeFromSuperlayer()

        guard chartContainer.bounds.width > 0 else { return }

        let maxValue = max(data?.totalIncome ?? 1, data?.totalExpenses ?? 1, 1)
        let barMaxHeight: CGFloat = 100
        let barWidth: CGFloat = 60
        let spacing: CGFloat = 40

        let incomeHeight = CGFloat((data?.totalIncome ?? 0) / maxValue) * barMaxHeight
        let expenseHeight = CGFloat((data?.totalExpenses ?? 0) / maxValue) * barMaxHeight

        let incomeX = (chartContainer.bounds.width - barWidth * 2 - spacing) / 2
        let expenseX = incomeX + barWidth + spacing

        let incomeY = barMaxHeight - incomeHeight + 30
        let expenseY = barMaxHeight - expenseHeight + 30

        let incomePath = UIBezierPath(roundedRect: CGRect(x: incomeX, y: incomeY, width: barWidth, height: max(4, incomeHeight)), cornerRadius: 8)
        let incomeBarLayer = CAShapeLayer()
        incomeBarLayer.path = incomePath.cgPath
        incomeBarLayer.fillColor = AppTheme.Colors.income.cgColor
        chartContainer.layer.addSublayer(incomeBarLayer)
        incomeBar = incomeBarLayer

        let expensePath = UIBezierPath(roundedRect: CGRect(x: expenseX, y: expenseY, width: barWidth, height: max(4, expenseHeight)), cornerRadius: 8)
        let expenseBarLayer = CAShapeLayer()
        expenseBarLayer.path = expensePath.cgPath
        expenseBarLayer.fillColor = AppTheme.Colors.expense.cgColor
        chartContainer.layer.addSublayer(expenseBarLayer)
        expenseBar = expenseBarLayer

        let labelFont = UIFont.systemFont(ofSize: 11, weight: .medium)

        let incomeTextLayer = CATextLayer()
        incomeTextLayer.string = data?.formattedIncome ?? "$0"
        incomeTextLayer.font = labelFont
        incomeTextLayer.fontSize = 11
        incomeTextLayer.foregroundColor = AppTheme.Colors.textPrimary.cgColor
        incomeTextLayer.alignmentMode = .center
        incomeTextLayer.contentsScale = UIScreen.main.scale
        incomeTextLayer.frame = CGRect(x: incomeX - 10, y: incomeY - 18, width: barWidth + 20, height: 16)
        chartContainer.layer.addSublayer(incomeTextLayer)
        incomeLabelLayer = incomeTextLayer

        let expenseTextLayer = CATextLayer()
        expenseTextLayer.string = data?.formattedExpenses ?? "$0"
        expenseTextLayer.font = labelFont
        expenseTextLayer.fontSize = 11
        expenseTextLayer.foregroundColor = AppTheme.Colors.textPrimary.cgColor
        expenseTextLayer.alignmentMode = .center
        expenseTextLayer.contentsScale = UIScreen.main.scale
        expenseTextLayer.frame = CGRect(x: expenseX - 10, y: expenseY - 18, width: barWidth + 20, height: 16)
        chartContainer.layer.addSublayer(expenseTextLayer)
        expenseLabelLayer = expenseTextLayer

        let incomeLegendLayer = CATextLayer()
        incomeLegendLayer.string = "Income"
        incomeLegendLayer.font = UIFont.systemFont(ofSize: 10)
        incomeLegendLayer.fontSize = 10
        incomeLegendLayer.foregroundColor = AppTheme.Colors.textSecondary.cgColor
        incomeLegendLayer.alignmentMode = .center
        incomeLegendLayer.contentsScale = UIScreen.main.scale
        incomeLegendLayer.frame = CGRect(x: incomeX - 10, y: barMaxHeight + 38, width: barWidth + 20, height: 14)
        chartContainer.layer.addSublayer(incomeLegendLayer)

        let expenseLegendLayer = CATextLayer()
        expenseLegendLayer.string = "Expenses"
        expenseLegendLayer.font = UIFont.systemFont(ofSize: 10)
        expenseLegendLayer.fontSize = 10
        expenseLegendLayer.foregroundColor = AppTheme.Colors.textSecondary.cgColor
        expenseLegendLayer.alignmentMode = .center
        expenseLegendLayer.contentsScale = UIScreen.main.scale
        expenseLegendLayer.frame = CGRect(x: expenseX - 10, y: barMaxHeight + 38, width: barWidth + 20, height: 14)
        chartContainer.layer.addSublayer(expenseLegendLayer)
    }

    private var data: IncomeVsExpenseData?
}

class MonthlyTrendChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let placeholderLabel = UILabel()

    private var expenseLineLayer: CAShapeLayer?
    private var incomeLineLayer: CAShapeLayer?
    private var data: [MonthlyTrendData] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Monthly Trend"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Recent cached months"
        subtitleLabel.font = AppTheme.Fonts.caption
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        placeholderLabel.text = "Load more months to view trends."
        placeholderLabel.font = AppTheme.Fonts.caption
        placeholderLabel.textColor = AppTheme.Colors.textMuted
        placeholderLabel.textAlignment = .center
        placeholderLabel.isHidden = true
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.heightAnchor.constraint(equalToConstant: 220),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            placeholderLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor)
        ])
    }

    func configure(with data: [MonthlyTrendData]) {
        self.data = data

        if data.count <= 1 {
            chartContainer.isHidden = true
            placeholderLabel.isHidden = false
            return
        }

        chartContainer.isHidden = false
        placeholderLabel.isHidden = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawChart()
    }

    private func drawChart() {
        expenseLineLayer?.removeFromSuperlayer()
        incomeLineLayer?.removeFromSuperlayer()

        chartContainer.layer.sublayers?.removeAll(where: { ($0 is CAShapeLayer) && $0 !== expenseLineLayer && $0 !== incomeLineLayer })

        guard data.count > 1 else { return }

        let allValues = data.flatMap { [$0.expenses, $0.incomes] }
        let maxValue = max(allValues.max() ?? 1, 1)

        let padding: CGFloat = 30
        let chartWidth = chartContainer.bounds.width - padding * 2
        let chartHeight = chartContainer.bounds.height - 20

        let pointSpacing = chartWidth / CGFloat(data.count - 1)

        var expensePath = UIBezierPath()
        var incomePath = UIBezierPath()

        for (index, item) in data.enumerated() {
            let x = padding + CGFloat(index) * pointSpacing
            let expenseY = chartHeight - CGFloat(item.expenses / maxValue) * (chartHeight - 20)
            let incomeY = chartHeight - CGFloat(item.incomes / maxValue) * (chartHeight - 20)

            if index == 0 {
                expensePath.move(to: CGPoint(x: x, y: expenseY))
                incomePath.move(to: CGPoint(x: x, y: incomeY))
            } else {
                expensePath.addLine(to: CGPoint(x: x, y: expenseY))
                incomePath.addLine(to: CGPoint(x: x, y: incomeY))
            }

            let monthLabel = CATextLayer()
            monthLabel.string = item.month
            monthLabel.font = UIFont.systemFont(ofSize: 9)
            monthLabel.fontSize = 9
            monthLabel.foregroundColor = AppTheme.Colors.textMuted.cgColor
            monthLabel.alignmentMode = .center
            monthLabel.contentsScale = UIScreen.main.scale
            monthLabel.frame = CGRect(x: x - 15, y: chartHeight + 2, width: 30, height: 12)
            chartContainer.layer.addSublayer(monthLabel)
        }

        let expenseLayer = CAShapeLayer()
        expenseLayer.path = expensePath.cgPath
        expenseLayer.strokeColor = AppTheme.Colors.expense.cgColor
        expenseLayer.fillColor = UIColor.clear.cgColor
        expenseLayer.lineWidth = 2.5
        expenseLayer.lineCap = .round
        expenseLayer.lineJoin = .round
        chartContainer.layer.addSublayer(expenseLayer)
        expenseLineLayer = expenseLayer

        let incomeLayer = CAShapeLayer()
        incomeLayer.path = incomePath.cgPath
        incomeLayer.strokeColor = AppTheme.Colors.income.cgColor
        incomeLayer.fillColor = UIColor.clear.cgColor
        incomeLayer.lineWidth = 2.5
        incomeLayer.lineCap = .round
        incomeLayer.lineJoin = .round
        chartContainer.layer.addSublayer(incomeLayer)
        incomeLineLayer = incomeLayer

        let legendContainer = UIView()
        legendContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(legendContainer)

        let expenseDot = UIView()
        expenseDot.backgroundColor = AppTheme.Colors.expense
        expenseDot.layer.cornerRadius = 4
        expenseDot.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(expenseDot)

        let expenseLegendLabel = UILabel()
        expenseLegendLabel.text = "Expenses"
        expenseLegendLabel.font = AppTheme.Fonts.small
        expenseLegendLabel.textColor = AppTheme.Colors.textSecondary
        expenseLegendLabel.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(expenseLegendLabel)

        let incomeDot = UIView()
        incomeDot.backgroundColor = AppTheme.Colors.income
        incomeDot.layer.cornerRadius = 4
        incomeDot.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(incomeDot)

        let incomeLegendLabel = UILabel()
        incomeLegendLabel.text = "Income"
        incomeLegendLabel.font = AppTheme.Fonts.small
        incomeLegendLabel.textColor = AppTheme.Colors.textSecondary
        incomeLegendLabel.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(incomeLegendLabel)

        NSLayoutConstraint.activate([
            legendContainer.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 4),
            legendContainer.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),

            expenseDot.leadingAnchor.constraint(equalTo: legendContainer.leadingAnchor),
            expenseDot.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            expenseDot.widthAnchor.constraint(equalToConstant: 8),
            expenseDot.heightAnchor.constraint(equalToConstant: 8),

            expenseLegendLabel.leadingAnchor.constraint(equalTo: expenseDot.trailingAnchor, constant: 4),
            expenseLegendLabel.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            expenseLegendLabel.trailingAnchor.constraint(equalTo: incomeDot.leadingAnchor, constant: -12),

            incomeDot.leadingAnchor.constraint(equalTo: expenseLegendLabel.trailingAnchor, constant: 12),
            incomeDot.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            incomeDot.widthAnchor.constraint(equalToConstant: 8),
            incomeDot.heightAnchor.constraint(equalToConstant: 8),

            incomeLegendLabel.leadingAnchor.constraint(equalTo: incomeDot.trailingAnchor, constant: 4),
            incomeLegendLabel.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            incomeLegendLabel.trailingAnchor.constraint(equalTo: legendContainer.trailingAnchor)
        ])
    }
}

class MonthlyComparisonChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let emptyLabel = UILabel()

    private var barLayers: [CAShapeLayer] = []
    private var data: [MonthlyExpenseData] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Monthly Expense Comparison"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Cached months"
        subtitleLabel.font = AppTheme.Fonts.caption
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.heightAnchor.constraint(equalToConstant: 220),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            emptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    func configure(with data: [MonthlyExpenseData], emptyMessage: String? = nil) {
        self.data = data.filter { $0.totalExpenses > 0 }

        if self.data.isEmpty {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.text = emptyMessage ?? "Load more months to compare spending."
            return
        }

        chartContainer.isHidden = false
        emptyLabel.isHidden = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawBars()
    }

    private func drawBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        chartContainer.layer.sublayers?.removeAll(where: { $0 is CATextLayer })

        guard !data.isEmpty, chartContainer.bounds.width > 0 else { return }

        let horizontalInset: CGFloat = 8
        let labelHeight: CGFloat = 16
        let topPadding: CGFloat = 8
        let availableWidth = chartContainer.bounds.width - (horizontalInset * 2)
        let availableHeight = chartContainer.bounds.height - labelHeight - topPadding

        let maxAmount = data.map { $0.totalExpenses }.max() ?? 1
        let slotWidth = availableWidth / CGFloat(data.count)
        let barWidth: CGFloat = min(32, slotWidth * 0.6)

        for (index, item) in data.enumerated() {
            let barHeight = max(4, CGFloat(item.totalExpenses / maxAmount) * (availableHeight - topPadding))
            let centerX = horizontalInset + slotWidth * CGFloat(index) + slotWidth / 2
            let x = centerX - barWidth / 2
            let y = availableHeight - barHeight + topPadding / 2

            let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight), cornerRadius: 4)
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.fillColor = AppTheme.Colors.expense.cgColor
            chartContainer.layer.addSublayer(layer)
            barLayers.append(layer)

            let textLayer = CATextLayer()
            textLayer.string = item.month
            textLayer.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            textLayer.fontSize = 10
            textLayer.foregroundColor = AppTheme.Colors.textSecondary.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.frame = CGRect(x: centerX - 20, y: availableHeight + 2, width: 40, height: labelHeight)
            chartContainer.layer.addSublayer(textLayer)

            if item.totalExpenses > 0 && barHeight > 20 {
                let amountLayer = CATextLayer()
                let shortAmount = shortAmountString(item.totalExpenses)
                amountLayer.string = shortAmount
                amountLayer.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
                amountLayer.fontSize = 9
                amountLayer.foregroundColor = UIColor.white.cgColor
                amountLayer.alignmentMode = .center
                amountLayer.contentsScale = UIScreen.main.scale
                amountLayer.frame = CGRect(x: centerX - 22, y: y + 2, width: 44, height: 14)
                chartContainer.layer.addSublayer(amountLayer)
            }
        }
    }

    private func shortAmountString(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "$%.1fk", amount / 1000)
        }
        return String(format: "$%.0f", amount)
    }
}

class IncomeVsExpenseMultiMonthChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let emptyLabel = UILabel()

    private var barLayers: [CAShapeLayer] = []
    private var data: [MonthlyExpenseData] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Income vs Expenses Over Time"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Cached months"
        subtitleLabel.font = AppTheme.Fonts.caption
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        let legendContainer = UIView()
        legendContainer.tag = 999
        legendContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(legendContainer)

        let incomeDot = UIView()
        incomeDot.backgroundColor = AppTheme.Colors.income
        incomeDot.layer.cornerRadius = 4
        incomeDot.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(incomeDot)

        let incomeLabel = UILabel()
        incomeLabel.text = "Income"
        incomeLabel.font = AppTheme.Fonts.small
        incomeLabel.textColor = AppTheme.Colors.textSecondary
        incomeLabel.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(incomeLabel)

        let expenseDot = UIView()
        expenseDot.backgroundColor = AppTheme.Colors.expense
        expenseDot.layer.cornerRadius = 4
        expenseDot.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(expenseDot)

        let expenseLabel = UILabel()
        expenseLabel.text = "Expenses"
        expenseLabel.font = AppTheme.Fonts.small
        expenseLabel.textColor = AppTheme.Colors.textSecondary
        expenseLabel.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(expenseLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.heightAnchor.constraint(equalToConstant: 220),

            legendContainer.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 8),
            legendContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            legendContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            incomeDot.leadingAnchor.constraint(equalTo: legendContainer.leadingAnchor),
            incomeDot.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            incomeDot.widthAnchor.constraint(equalToConstant: 8),
            incomeDot.heightAnchor.constraint(equalToConstant: 8),

            incomeLabel.leadingAnchor.constraint(equalTo: incomeDot.trailingAnchor, constant: 4),
            incomeLabel.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),

            expenseDot.leadingAnchor.constraint(equalTo: incomeLabel.trailingAnchor, constant: 12),
            expenseDot.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            expenseDot.widthAnchor.constraint(equalToConstant: 8),
            expenseDot.heightAnchor.constraint(equalToConstant: 8),

            expenseLabel.leadingAnchor.constraint(equalTo: expenseDot.trailingAnchor, constant: 4),
            expenseLabel.centerYAnchor.constraint(equalTo: legendContainer.centerYAnchor),
            expenseLabel.trailingAnchor.constraint(equalTo: legendContainer.trailingAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    func configure(with data: [MonthlyExpenseData], emptyMessage: String? = nil) {
        self.data = data.filter { $0.totalExpenses > 0 || $0.totalIncome > 0 }

        if self.data.isEmpty {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.text = emptyMessage ?? "Load another month to compare income and expenses."
            return
        }

        chartContainer.isHidden = false
        emptyLabel.isHidden = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawBars()
    }

    private func drawBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        chartContainer.layer.sublayers?.removeAll(where: { $0 is CATextLayer })

        guard !data.isEmpty, chartContainer.bounds.width > 0 else { return }

        let horizontalInset: CGFloat = 8
        let labelHeight: CGFloat = 16
        let topPadding: CGFloat = 8
        let availableWidth = chartContainer.bounds.width - (horizontalInset * 2)
        let availableHeight = chartContainer.bounds.height - labelHeight - topPadding

        let maxAmount = data.flatMap { [$0.totalExpenses, $0.totalIncome] }.max() ?? 1
        let slotWidth = availableWidth / CGFloat(data.count)
        let pairWidth: CGFloat = min(50, slotWidth * 0.7)
        let barWidth: CGFloat = pairWidth / 2 - 2

        for (index, item) in data.enumerated() {
            let slotCenterX = horizontalInset + slotWidth * CGFloat(index) + slotWidth / 2
            let incomeX = slotCenterX - pairWidth / 2
            let expenseX = slotCenterX + 2

            let incomeBarHeight = max(4, CGFloat(item.totalIncome / maxAmount) * (availableHeight - topPadding))
            let expenseBarHeight = max(4, CGFloat(item.totalExpenses / maxAmount) * (availableHeight - topPadding))

            let incomeY = availableHeight - incomeBarHeight + topPadding / 2
            let expenseY = availableHeight - expenseBarHeight + topPadding / 2

            let incomePath = UIBezierPath(roundedRect: CGRect(x: incomeX, y: incomeY, width: barWidth, height: incomeBarHeight), cornerRadius: 3)
            let incomeLayer = CAShapeLayer()
            incomeLayer.path = incomePath.cgPath
            incomeLayer.fillColor = AppTheme.Colors.income.cgColor
            chartContainer.layer.addSublayer(incomeLayer)
            barLayers.append(incomeLayer)

            let expensePath = UIBezierPath(roundedRect: CGRect(x: expenseX, y: expenseY, width: barWidth, height: expenseBarHeight), cornerRadius: 3)
            let expenseLayer = CAShapeLayer()
            expenseLayer.path = expensePath.cgPath
            expenseLayer.fillColor = AppTheme.Colors.expense.cgColor
            chartContainer.layer.addSublayer(expenseLayer)
            barLayers.append(expenseLayer)

            let textLayer = CATextLayer()
            textLayer.string = item.month
            textLayer.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            textLayer.fontSize = 10
            textLayer.foregroundColor = AppTheme.Colors.textSecondary.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.frame = CGRect(x: slotCenterX - 20, y: availableHeight + 2, width: 40, height: labelHeight)
            chartContainer.layer.addSublayer(textLayer)
        }
    }
}

class CategoryTrendChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let emptyLabel = UILabel()

    private var barLayers: [CAShapeLayer] = []
    private var data: [MonthlyExpenseData] = []
    private var topCategories: [String] = []

    private let categoryColors: [UIColor] = [
        AppTheme.Colors.expense,
        AppTheme.Colors.secondaryBrown,
        AppTheme.Colors.income,
        AppTheme.Colors.accentSecondary,
        AppTheme.Colors.expenseLight
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Category Trends"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Top spending categories over cached months"
        subtitleLabel.font = AppTheme.Fonts.caption
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        let legendContainer = UIView()
        legendContainer.tag = 999
        legendContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(legendContainer)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.heightAnchor.constraint(equalToConstant: 220),

            legendContainer.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 8),
            legendContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            legendContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            legendContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            emptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    func configure(with data: [MonthlyExpenseData], topCategories: [String], emptyMessage: String? = nil) {
        self.data = data
        self.topCategories = topCategories

        let hasData = data.contains { $0.totalExpenses > 0 }

        if !hasData || topCategories.isEmpty {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.text = emptyMessage ?? "Load more months to view category trends."
            return
        }

        chartContainer.isHidden = false
        emptyLabel.isHidden = true
        buildLegend()
        setNeedsLayout()
    }

    private func buildLegend() {
        guard let legendContainer = viewWithTag(999) else { return }
        legendContainer.subviews.forEach { $0.removeFromSuperview() }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        legendContainer.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: legendContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: legendContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: legendContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: legendContainer.bottomAnchor)
        ])

        for (index, category) in topCategories.enumerated() {
            let color = categoryColors[index % categoryColors.count]
            let item = createLegendItem(color: color, label: category)
            stackView.addArrangedSubview(item)
        }
    }

    private func createLegendItem(color: UIColor, label: String) -> UIView {
        let container = UIView()

        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dot)

        let labelView = UILabel()
        labelView.text = label
        labelView.font = AppTheme.Fonts.small
        labelView.textColor = AppTheme.Colors.textSecondary
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelView)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            labelView.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 4),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawBars()
    }

    private func drawBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        chartContainer.layer.sublayers?.removeAll(where: { $0 is CATextLayer })

        guard !data.isEmpty, !topCategories.isEmpty, chartContainer.bounds.width > 0 else { return }

        let horizontalInset: CGFloat = 8
        let labelHeight: CGFloat = 16
        let topPadding: CGFloat = 8
        let availableWidth = chartContainer.bounds.width - (horizontalInset * 2)
        let availableHeight = chartContainer.bounds.height - labelHeight - topPadding

        var maxTotal: Double = 0
        for item in data {
            var monthTotal: Double = 0
            for cat in topCategories {
                monthTotal += item.categoryTotals[cat] ?? 0
            }
            maxTotal = max(maxTotal, monthTotal)
        }
        if maxTotal == 0 { return }

        let slotWidth = availableWidth / CGFloat(data.count)
        let barWidth: CGFloat = min(40, slotWidth * 0.6)

        for (index, item) in data.enumerated() {
            let centerX = horizontalInset + slotWidth * CGFloat(index) + slotWidth / 2
            let x = centerX - barWidth / 2

            var currentY = availableHeight + topPadding / 2

            for (catIndex, category) in topCategories.enumerated() {
                let amount = item.categoryTotals[category] ?? 0
                if amount == 0 { continue }

                let segmentHeight = max(2, CGFloat(amount / maxTotal) * (availableHeight - topPadding))
                currentY -= segmentHeight

                let color = categoryColors[catIndex % categoryColors.count]
                let path = UIBezierPath(roundedRect: CGRect(x: x, y: currentY, width: barWidth, height: segmentHeight), cornerRadius: 2)
                let layer = CAShapeLayer()
                layer.path = path.cgPath
                layer.fillColor = color.cgColor
                chartContainer.layer.addSublayer(layer)
                barLayers.append(layer)
            }

            let textLayer = CATextLayer()
            textLayer.string = item.month
            textLayer.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            textLayer.fontSize = 10
            textLayer.foregroundColor = AppTheme.Colors.textSecondary.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.frame = CGRect(x: centerX - 20, y: availableHeight + 2, width: 40, height: labelHeight)
            chartContainer.layer.addSublayer(textLayer)
        }
    }
}