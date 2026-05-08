//
//  DashboardViewController.swift
//  Notra
//

import UIKit

class DashboardViewController: UIViewController {

    private let viewModel: DashboardViewModel

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let monthSelectorButton = UIButton(type: .system)
    private let expenseCard = DashboardCardView(title: "Expenses", color: .systemRed)
    private let incomeCard = DashboardCardView(title: "Income", color: .systemGreen)
    private let balanceCard = DashboardCardView(title: "Balance", color: .systemBlue)

    private let expenseButton = UIButton(type: .system)
    private let incomeButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let progressLabel = UILabel()

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
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: refreshButton)

        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
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

        setupMonthSelector()
        setupCards()
        setupButtons()
        setupActivityIndicator()
    }

    private func setupMonthSelector() {
        monthSelectorButton.setTitle("May 2026 \u{25BC}", for: .normal)
        monthSelectorButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        monthSelectorButton.setTitleColor(.label, for: .normal)
        monthSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        monthSelectorButton.addTarget(self, action: #selector(monthSelectorTapped), for: .touchUpInside)
        contentView.addSubview(monthSelectorButton)

        NSLayoutConstraint.activate([
            monthSelectorButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            monthSelectorButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    private func setupCards() {
        expenseCard.translatesAutoresizingMaskIntoConstraints = false
        incomeCard.translatesAutoresizingMaskIntoConstraints = false
        balanceCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expenseCard)
        contentView.addSubview(incomeCard)
        contentView.addSubview(balanceCard)

        NSLayoutConstraint.activate([
            expenseCard.topAnchor.constraint(equalTo: monthSelectorButton.bottomAnchor, constant: 24),
            expenseCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            expenseCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            expenseCard.heightAnchor.constraint(equalToConstant: 100),

            incomeCard.topAnchor.constraint(equalTo: expenseCard.bottomAnchor, constant: 12),
            incomeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            incomeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            incomeCard.heightAnchor.constraint(equalToConstant: 100),

            balanceCard.topAnchor.constraint(equalTo: incomeCard.bottomAnchor, constant: 12),
            balanceCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            balanceCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            balanceCard.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func setupButtons() {
        expenseButton.setTitle("View Expenses", for: .normal)
        expenseButton.backgroundColor = .systemRed.withAlphaComponent(0.1)
        expenseButton.setTitleColor(.systemRed, for: .normal)
        expenseButton.layer.cornerRadius = 12
        expenseButton.translatesAutoresizingMaskIntoConstraints = false
        expenseButton.addTarget(self, action: #selector(viewExpensesTapped), for: .touchUpInside)
        contentView.addSubview(expenseButton)

        incomeButton.setTitle("View Income", for: .normal)
        incomeButton.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        incomeButton.setTitleColor(.systemGreen, for: .normal)
        incomeButton.layer.cornerRadius = 12
        incomeButton.translatesAutoresizingMaskIntoConstraints = false
        incomeButton.addTarget(self, action: #selector(viewIncomeTapped), for: .touchUpInside)
        contentView.addSubview(incomeButton)

        NSLayoutConstraint.activate([
            expenseButton.topAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: 32),
            expenseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            expenseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            expenseButton.heightAnchor.constraint(equalToConstant: 50),

            incomeButton.topAnchor.constraint(equalTo: expenseButton.bottomAnchor, constant: 12),
            incomeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            incomeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            incomeButton.heightAnchor.constraint(equalToConstant: 50),
            incomeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        progressLabel.textAlignment = .center
        progressLabel.font = .systemFont(ofSize: 14)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
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

    private func updateUI() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        let monthDisplay = viewModel.getMonthDisplayString(for: viewModel.selectedMonth)
        monthSelectorButton.setTitle("\(monthDisplay) \u{25BC}", for: .normal)

        expenseCard.setValue(formatter.string(from: NSNumber(value: viewModel.selectedMonthExpenses)) ?? "$0")
        expenseCard.setSubtitle("\(viewModel.selectedMonthExpensesCount) transactions")

        incomeCard.setValue(formatter.string(from: NSNumber(value: viewModel.selectedMonthIncomes)) ?? "$0")
        incomeCard.setSubtitle("\(viewModel.selectedMonthIncomesCount) transactions")

        let balance = viewModel.balance
        let balanceColor: UIColor = balance >= 0 ? .systemGreen : .systemRed
        balanceCard.backgroundColor = balanceColor.withAlphaComponent(0.1)
        balanceCard.titleLabel.textColor = balanceColor
        balanceCard.setValue(formatter.string(from: NSNumber(value: abs(balance))) ?? "$0")
        balanceCard.setSubtitle(balance >= 0 ? "Positive" : "Negative")
    }
}

extension DashboardViewController: DashboardViewModelDelegate {
    func didStartLoading() {
        activityIndicator.startAnimating()
        progressLabel.text = "Loading..."
        scrollView.isHidden = true
    }

    func didFinishLoading(success: Bool, error: Error?) {
        activityIndicator.stopAnimating()
        progressLabel.text = ""
        scrollView.isHidden = false

        if success {
            updateUI()
        } else {
            let alert = UIAlertController(title: "Error", message: error?.localizedDescription ?? "Failed to load data", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    func didUpdateProgress(current: Int, total: Int) {
        progressLabel.text = "Loading \(current) of \(total) databases..."
    }

    func didUpdateMonthSelection() {
        updateUI()
    }
}

class DashboardCardView: UIView {
    let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(title: String, color: UIColor) {
        super.init(frame: .zero)

        backgroundColor = color.withAlphaComponent(0.1)
        layer.cornerRadius = 12

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = color

        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .label

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(subtitleLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }

    func setSubtitle(_ subtitle: String) {
        subtitleLabel.text = subtitle
    }
}