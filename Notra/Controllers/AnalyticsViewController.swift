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

    private let emptyView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        return view
    }()
    private let headerView = UIView()
    private let monthSelectorButton = UIButton(type: .system)

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

        navigationController?.navigationBar.prefersLargeTitles = true
        if let navBar = navigationController?.navigationBar {
            AppTheme.styleNavigationBar(navBar)
        }

        setupScrollView()
        setupEmptyState()
        setupHeader()
        setupSummaryCards()
        setupExpenseSection()
        setupDailySpendingSection()
        setupIncomeVsExpenseSection()
        setupIncomeSection()
        setupMonthlyTrendSection()
        setupInsightsSection()

        setupCustomSpacing()
    }

    private func setupCustomSpacing() {
        contentStackView.setCustomSpacing(12, after: headerView)
        contentStackView.setCustomSpacing(16, after: expenseSectionLabel)
        contentStackView.setCustomSpacing(32, after: expenseStackView)
        contentStackView.setCustomSpacing(16, after: dailySpendingSectionLabel)
        contentStackView.setCustomSpacing(32, after: dailySpendingStackView)
        contentStackView.setCustomSpacing(16, after: incomeVsExpenseSectionLabel)
        contentStackView.setCustomSpacing(32, after: incomeVsExpenseStackView)
        contentStackView.setCustomSpacing(16, after: incomeSectionLabel)
        contentStackView.setCustomSpacing(32, after: incomeStackView)
        contentStackView.setCustomSpacing(16, after: monthlyTrendSectionLabel)
        contentStackView.setCustomSpacing(32, after: monthlyTrendStackView)
        contentStackView.setCustomSpacing(16, after: insightsSectionLabel)
        contentStackView.setCustomSpacing(32, after: insightsStackView)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        let iconView = UIImageView(image: UIImage(systemName: "chart.bar.xaxis"))
        iconView.tintColor = AppTheme.Colors.textMuted
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(iconView)

        let label = UILabel()
        label.text = "No analytics available"
        label.font = AppTheme.Fonts.headingMedium
        label.textColor = AppTheme.Colors.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "Load dashboard data or refresh from Notion to see insights."
        sublabel.font = AppTheme.Fonts.body
        sublabel.textColor = AppTheme.Colors.textMuted
        sublabel.textAlignment = .center
        sublabel.numberOfLines = 0
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(sublabel)

        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            iconView.topAnchor.constraint(equalTo: emptyView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),

            sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            sublabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            sublabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
            sublabel.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor)
        ])
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(headerView)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.year = viewModel.selectedMonth.year
        components.month = viewModel.selectedMonth.month
        components.day = 1

        let displayDate = Calendar.current.date(from: components) ?? Date()
        monthSelectorButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        monthSelectorButton.semanticContentAttribute = .forceRightToLeft
        monthSelectorButton.setTitle(" \(formatter.string(from: displayDate)) ", for: .normal)
        monthSelectorButton.titleLabel?.font = AppTheme.Fonts.bodyMedium
        monthSelectorButton.setTitleColor(AppTheme.Colors.primaryBrown, for: .normal)
        monthSelectorButton.tintColor = AppTheme.Colors.primaryBrown
        monthSelectorButton.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        monthSelectorButton.layer.cornerRadius = AppTheme.CornerRadius.pill
        monthSelectorButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        monthSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        monthSelectorButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
        headerView.addSubview(monthSelectorButton)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            monthSelectorButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            monthSelectorButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            monthSelectorButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
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
        valueLabel.minimumScaleFactor = 0.75
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
        expenseStackView.spacing = 12
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
        dailySpendingSectionLabel.text = ""
        dailySpendingSectionLabel.font = AppTheme.Fonts.sectionHeader
        dailySpendingSectionLabel.textColor = AppTheme.Colors.textPrimary
        dailySpendingSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(dailySpendingSectionLabel)

        dailySpendingStackView.axis = .vertical
        dailySpendingStackView.spacing = 12
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
        incomeStackView.spacing = 12
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

    private func loadData() {
        viewModel.loadAnalytics()

        if viewModel.hasData {
            scrollView.isHidden = false
            emptyView.isHidden = true
            updateUI()
        } else {
            scrollView.isHidden = true
            emptyView.isHidden = false
        }
    }

    private func updateUI() {
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

        expenseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if !viewModel.expenseCategories.isEmpty {
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.expenseCategories, totalAmount: viewModel.totalExpenses, color: AppTheme.Colors.expense)
            expenseStackView.addArrangedSubview(donutChart)
            donutChart.heightAnchor.constraint(equalToConstant: 280).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No expenses this month"
            emptyLabel.font = AppTheme.Fonts.caption
            emptyLabel.textColor = AppTheme.Colors.textMuted
            expenseStackView.addArrangedSubview(emptyLabel)
            emptyLabel.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        dailySpendingStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.hasDailySpending {
            let dailyChart = DailySpendingChartView()
            dailyChart.configure(with: viewModel.dailySpendingData)
            dailySpendingStackView.addArrangedSubview(dailyChart)
            dailyChart.heightAnchor.constraint(equalToConstant: 300).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No expenses for this month yet."
            emptyLabel.font = AppTheme.Fonts.caption
            emptyLabel.textColor = AppTheme.Colors.textMuted
            dailySpendingStackView.addArrangedSubview(emptyLabel)
            emptyLabel.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        incomeVsExpenseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let incomeVsData = viewModel.incomeVsExpenseData {
            let comparisonChart = IncomeVsExpenseChartView()
            comparisonChart.configure(with: incomeVsData)
            incomeVsExpenseStackView.addArrangedSubview(comparisonChart)
            comparisonChart.heightAnchor.constraint(equalToConstant: 280).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No data available"
            emptyLabel.font = AppTheme.Fonts.caption
            emptyLabel.textColor = AppTheme.Colors.textMuted
            incomeVsExpenseStackView.addArrangedSubview(emptyLabel)
            emptyLabel.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        incomeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if !viewModel.incomeCategories.isEmpty {
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.incomeCategories, totalAmount: viewModel.totalIncomes, color: AppTheme.Colors.income)
            incomeStackView.addArrangedSubview(donutChart)
            donutChart.heightAnchor.constraint(equalToConstant: 280).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No income this month"
            emptyLabel.font = AppTheme.Fonts.caption
            emptyLabel.textColor = AppTheme.Colors.textMuted
            incomeStackView.addArrangedSubview(emptyLabel)
            emptyLabel.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        monthlyTrendStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if viewModel.hasMonthlyTrend {
            let trendChart = MonthlyTrendChartView()
            trendChart.configure(with: viewModel.monthlyTrendData)
            monthlyTrendStackView.addArrangedSubview(trendChart)
            trendChart.heightAnchor.constraint(equalToConstant: 300).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "Load more months to view trends."
            emptyLabel.font = AppTheme.Fonts.caption
            emptyLabel.textColor = AppTheme.Colors.textMuted
            monthlyTrendStackView.addArrangedSubview(emptyLabel)
            emptyLabel.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }

        insightsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let topCategory = viewModel.topSpendingCategory {
            addInsightRow(icon: "arrow.up.circle.fill", title: "Top Spending", value: topCategory, color: AppTheme.Colors.expense)
        }

        if let highestDay = viewModel.highestSpendingDay {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let amountStr = formatter.string(from: NSNumber(value: viewModel.highestSpendingDayAmount)) ?? "$0"
            addInsightRow(icon: "calendar", title: "Highest Spending Day", value: "\(highestDay) (\(amountStr))", color: AppTheme.Colors.accent)
        }

        addInsightRow(icon: "list.bullet", title: "Total Expenses", value: "\(viewModel.expenseTransactionCount) transactions", color: AppTheme.Colors.expense)
        addInsightRow(icon: "plus.circle.fill", title: "Total Income", value: "\(viewModel.incomeTransactionCount) transactions", color: AppTheme.Colors.income)

        view.layoutIfNeeded()
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
        AppTheme.applyCardStyle(to: self)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        centerLabel.font = AppTheme.Fonts.headingMedium
        centerLabel.textColor = AppTheme.Colors.textPrimary
        centerLabel.textAlignment = .center
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
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.widthAnchor.constraint(equalToConstant: 180),
            chartContainer.heightAnchor.constraint(equalToConstant: 180),

            centerLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor, constant: -8),

            centerSubtitleLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerSubtitleLabel.topAnchor.constraint(equalTo: centerLabel.bottomAnchor, constant: 2),

            legendStackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            legendStackView.leadingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: 20),
            legendStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            legendStackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
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
        let container = UIView()

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 5
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorDot)

        let labelView = UILabel()
        labelView.text = label
        labelView.font = AppTheme.Fonts.captionMedium
        labelView.textColor = AppTheme.Colors.textPrimary
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelView)

        let amountView = UILabel()
        amountView.text = "\(amount) (\(Int(percentage))%)"
        amountView.font = AppTheme.Fonts.small
        amountView.textColor = AppTheme.Colors.textSecondary
        amountView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(amountView)

        NSLayoutConstraint.activate([
            colorDot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 10),
            colorDot.heightAnchor.constraint(equalToConstant: 10),

            labelView.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 8),
            labelView.topAnchor.constraint(equalTo: container.topAnchor),

            amountView.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 8),
            amountView.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 2),
            amountView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }
}

class DailySpendingChartView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chartContainer = UIView()
    private let emptyLabel = UILabel()

    private var bars: [CAShapeLayer] = []
    private var data: [DailySpendingData] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        AppTheme.applyCardStyle(to: self)

        titleLabel.text = "Daily Spending"
        titleLabel.font = AppTheme.Fonts.sectionHeader
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Spending by day"
        subtitleLabel.font = AppTheme.Fonts.caption
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        emptyLabel.text = "No expenses for this month yet."
        emptyLabel.font = AppTheme.Fonts.caption
        emptyLabel.textColor = AppTheme.Colors.textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            chartContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartContainer.heightAnchor.constraint(equalToConstant: 200),
            chartContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            emptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor)
        ])
    }

    func configure(with data: [DailySpendingData]) {
        self.data = data.filter { $0.amount > 0 }

        if self.data.isEmpty {
            chartContainer.isHidden = true
            emptyLabel.isHidden = false
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
        bars.forEach { $0.removeFromSuperlayer() }
        bars.removeAll()
        chartContainer.layer.sublayers?.removeAll(where: { $0 is CATextLayer })

        guard !data.isEmpty else { return }

        let maxAmount = data.map { $0.amount }.max() ?? 1
        let barWidth: CGFloat = 6
        let labelHeight: CGFloat = 16
        let availableHeight = chartContainer.bounds.height - labelHeight - 4
        let minSpacing: CGFloat = data.count > 20 ? 2 : (data.count > 10 ? 3 : 4)
        let spacing: CGFloat = max(minSpacing, (chartContainer.bounds.width - CGFloat(data.count) * barWidth) / CGFloat(data.count + 1))
        let startX = spacing

        let labelIndices = calculateLabelIndices(count: data.count)

        for (index, item) in data.enumerated() {
            let normalizedHeight = maxAmount > 0 ? CGFloat(item.amount / maxAmount) * (availableHeight - 8) : 0
            let barHeight = max(4, normalizedHeight)
            let x = startX + CGFloat(index) * (barWidth + spacing)
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
                textLayer.frame = CGRect(x: x - 8, y: chartContainer.bounds.height - labelHeight + 2, width: barWidth + 16, height: labelHeight)
                chartContainer.layer.addSublayer(textLayer)
            }
        }
    }

    private func calculateLabelIndices(count: Int) -> Set<Int> {
        var indices = Set<Int>()
        for i in 0..<count { indices.insert(i) }
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