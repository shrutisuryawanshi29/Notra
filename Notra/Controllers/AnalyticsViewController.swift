//
//  AnalyticsViewController.swift
//  Notra
//

import UIKit

class AnalyticsViewController: UIViewController {

    private let viewModel: AnalyticsViewModel

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let emptyView = UIView()
    private let headerView = UIView()
    private let monthSelectorButton = UIButton(type: .system)

    private let summaryStackView = UIStackView()
    private let expenseSummaryCard = SummaryCardView()
    private let incomeSummaryCard = SummaryCardView()
    private let balanceSummaryCard = SummaryCardView()

    private let expenseSectionLabel = UILabel()
    private let expenseStackView = UIStackView()

    private let incomeSectionLabel = UILabel()
    private let incomeStackView = UIStackView()

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

    private func setupUI() {
        title = "Analytics"
        view.backgroundColor = .systemGroupedBackground

        navigationController?.navigationBar.prefersLargeTitles = true

        setupScrollView()
        setupEmptyState()
        setupHeader()
        setupSummaryCards()
        setupExpenseSection()
        setupIncomeSection()
        setupInsightsSection()
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

    private func setupEmptyState() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        let iconView = UIImageView(image: UIImage(systemName: "chart.bar.xaxis"))
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(iconView)

        let label = UILabel()
        label.text = "No analytics available"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "Load dashboard data or refresh from Notion to see insights."
        sublabel.font = .systemFont(ofSize: 14)
        sublabel.textColor = .tertiaryLabel
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
        contentView.addSubview(headerView)

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
        monthSelectorButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        monthSelectorButton.setTitleColor(.label, for: .normal)
        monthSelectorButton.tintColor = .label
        monthSelectorButton.backgroundColor = .secondarySystemGroupedBackground
        monthSelectorButton.layer.cornerRadius = 10
        monthSelectorButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        monthSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        monthSelectorButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
        headerView.addSubview(monthSelectorButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

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
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 12
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(summaryStackView)

        expenseSummaryCard.configure(title: "Total Expenses", icon: "arrow.up.circle.fill", color: .systemRed)
        incomeSummaryCard.configure(title: "Total Income", icon: "arrow.down.circle.fill", color: .systemGreen)
        balanceSummaryCard.configure(title: "Net Balance", icon: "wallet.pass.fill", color: .systemBlue)

        summaryStackView.addArrangedSubview(expenseSummaryCard)
        summaryStackView.addArrangedSubview(incomeSummaryCard)
        summaryStackView.addArrangedSubview(balanceSummaryCard)

        NSLayoutConstraint.activate([
            summaryStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            summaryStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            summaryStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupExpenseSection() {
        expenseSectionLabel.text = "Expense Categories"
        expenseSectionLabel.font = .systemFont(ofSize: 20, weight: .bold)
        expenseSectionLabel.textColor = .label
        expenseSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expenseSectionLabel)

        expenseStackView.axis = .vertical
        expenseStackView.spacing = 12
        expenseStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expenseStackView)

        NSLayoutConstraint.activate([
            expenseSectionLabel.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 28),
            expenseSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            expenseSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            expenseStackView.topAnchor.constraint(equalTo: expenseSectionLabel.bottomAnchor, constant: 12),
            expenseStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            expenseStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupIncomeSection() {
        incomeSectionLabel.text = "Income Sources"
        incomeSectionLabel.font = .systemFont(ofSize: 20, weight: .bold)
        incomeSectionLabel.textColor = .label
        incomeSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(incomeSectionLabel)

        incomeStackView.axis = .vertical
        incomeStackView.spacing = 12
        incomeStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(incomeStackView)

        NSLayoutConstraint.activate([
            incomeSectionLabel.topAnchor.constraint(equalTo: expenseStackView.bottomAnchor, constant: 28),
            incomeSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            incomeSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            incomeStackView.topAnchor.constraint(equalTo: incomeSectionLabel.bottomAnchor, constant: 12),
            incomeStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            incomeStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupInsightsSection() {
        insightsSectionLabel.text = "Insights"
        insightsSectionLabel.font = .systemFont(ofSize: 20, weight: .bold)
        insightsSectionLabel.textColor = .label
        insightsSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(insightsSectionLabel)

        insightsStackView.axis = .vertical
        insightsStackView.spacing = 12
        insightsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(insightsStackView)

        NSLayoutConstraint.activate([
            insightsSectionLabel.topAnchor.constraint(equalTo: incomeStackView.bottomAnchor, constant: 28),
            insightsSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            insightsSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            insightsStackView.topAnchor.constraint(equalTo: insightsSectionLabel.bottomAnchor, constant: 12),
            insightsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            insightsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            insightsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
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
        expenseSummaryCard.setValue(viewModel.formattedTotalExpenses)
        expenseSummaryCard.setSubtitle("\(viewModel.expenseTransactionCount) transactions")

        incomeSummaryCard.setValue(viewModel.formattedTotalIncomes)
        incomeSummaryCard.setSubtitle("\(viewModel.incomeTransactionCount) transactions")

        let balanceColor: UIColor = viewModel.netBalance >= 0 ? .systemGreen : .systemRed
        balanceSummaryCard.setValue(viewModel.formattedNetBalance)
        balanceSummaryCard.setValueColor(balanceColor)
        balanceSummaryCard.setSubtitle(viewModel.netBalance >= 0 ? "You saved" : "Over budget")

        expenseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if !viewModel.expenseCategories.isEmpty {
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.expenseCategories, totalAmount: viewModel.totalExpenses, color: .systemRed)
            expenseStackView.addArrangedSubview(donutChart)
            donutChart.heightAnchor.constraint(equalToConstant: 200).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No expenses this month"
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = .tertiaryLabel
            expenseStackView.addArrangedSubview(emptyLabel)
        }

        incomeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if !viewModel.incomeCategories.isEmpty {
            let donutChart = DonutChartView()
            donutChart.configure(with: viewModel.incomeCategories, totalAmount: viewModel.totalIncomes, color: .systemGreen)
            incomeStackView.addArrangedSubview(donutChart)
            donutChart.heightAnchor.constraint(equalToConstant: 200).isActive = true
        } else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No income this month"
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = .tertiaryLabel
            incomeStackView.addArrangedSubview(emptyLabel)
        }

        insightsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let topCategory = viewModel.topSpendingCategory {
            addInsightRow(icon: "arrow.up.circle.fill", title: "Top Spending", value: topCategory, color: .systemRed)
        }

        if let highestDay = viewModel.highestSpendingDay {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let amountStr = formatter.string(from: NSNumber(value: viewModel.highestSpendingDayAmount)) ?? "$0"
            addInsightRow(icon: "calendar", title: "Highest Spending Day", value: "\(highestDay) (\(amountStr))", color: .systemOrange)
        }

        addInsightRow(icon: "list.bullet", title: "Total Expenses", value: "\(viewModel.expenseTransactionCount) transactions", color: .systemRed)
        addInsightRow(icon: "plus.circle.fill", title: "Total Income", value: "\(viewModel.incomeTransactionCount) transactions", color: .systemGreen)
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
        categoryLabel.font = .systemFont(ofSize: 15, weight: .medium)
        categoryLabel.textColor = .label
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(categoryLabel)

        amountLabel.font = .systemFont(ofSize: 14)
        amountLabel.textColor = .secondaryLabel
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(amountLabel)

        percentageLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        percentageLabel.textColor = .secondaryLabel
        percentageLabel.textAlignment = .right
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(percentageLabel)

        progressBar.backgroundColor = UIColor.systemGray5
        progressBar.layer.cornerRadius = 4
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressBar)

        progressFill.layer.cornerRadius = 4
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
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemIndigo
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .label
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

class DonutChartView: UIView {
    private let chartContainer = UIView()
    private let legendStackView = UIStackView()
    private var segments: [(color: UIColor, percentage: Double, label: String, amount: String)] = []
    private var centerLabel = UILabel()
    private var centerSubtitleLabel = UILabel()
    private var chartLayers: [CAShapeLayer] = []

    private let chartColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartContainer)

        centerLabel.font = .systemFont(ofSize: 18, weight: .bold)
        centerLabel.textColor = .label
        centerLabel.textAlignment = .center
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(centerLabel)

        centerSubtitleLabel.font = .systemFont(ofSize: 11)
        centerSubtitleLabel.textColor = .secondaryLabel
        centerSubtitleLabel.textAlignment = .center
        centerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(centerSubtitleLabel)

        legendStackView.axis = .vertical
        legendStackView.spacing = 6
        legendStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(legendStackView)

        NSLayoutConstraint.activate([
            chartContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            chartContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartContainer.widthAnchor.constraint(equalToConstant: 120),
            chartContainer.heightAnchor.constraint(equalToConstant: 120),

            centerLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor, constant: -6),

            centerSubtitleLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            centerSubtitleLabel.topAnchor.constraint(equalTo: centerLabel.bottomAnchor, constant: 2),

            legendStackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            legendStackView.leadingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: 16),
            legendStackView.trailingAnchor.constraint(equalTo: trailingAnchor)
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
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.textColor = .label
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelView)

        let amountView = UILabel()
        amountView.text = "\(amount) (\(Int(percentage))%)"
        amountView.font = .systemFont(ofSize: 12)
        amountView.textColor = .secondaryLabel
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