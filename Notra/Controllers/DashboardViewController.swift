//
//  DashboardViewController.swift
//  Notra
//

import UIKit

class DashboardViewController: UIViewController {

    private let viewModel: DashboardViewModel

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let currentMonthLabel = UILabel()
    private let expenseCard = DashboardCardView(title: "Expenses", color: .systemRed)
    private let incomeCard = DashboardCardView(title: "Income", color: .systemGreen)

    private let previousMonthLabel = UILabel()
    private let previousExpenseCard = DashboardCardView(title: "Previous Month Expenses", color: .systemOrange)
    private let previousIncomeCard = DashboardCardView(title: "Previous Month Income", color: .systemTeal)

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

        setupCurrentMonthSection()
        setupPreviousMonthSection()
        setupButtons()
        setupActivityIndicator()
    }

    private func setupCurrentMonthSection() {
        currentMonthLabel.text = "This Month"
        currentMonthLabel.font = .systemFont(ofSize: 20, weight: .bold)
        currentMonthLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(currentMonthLabel)

        expenseCard.translatesAutoresizingMaskIntoConstraints = false
        incomeCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expenseCard)
        contentView.addSubview(incomeCard)

        NSLayoutConstraint.activate([
            currentMonthLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            currentMonthLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            expenseCard.topAnchor.constraint(equalTo: currentMonthLabel.bottomAnchor, constant: 12),
            expenseCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            expenseCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            expenseCard.heightAnchor.constraint(equalToConstant: 100),

            incomeCard.topAnchor.constraint(equalTo: expenseCard.bottomAnchor, constant: 12),
            incomeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            incomeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            incomeCard.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func setupPreviousMonthSection() {
        previousMonthLabel.text = "Previous Month"
        previousMonthLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        previousMonthLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previousMonthLabel)

        previousExpenseCard.translatesAutoresizingMaskIntoConstraints = false
        previousIncomeCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previousExpenseCard)
        contentView.addSubview(previousIncomeCard)

        NSLayoutConstraint.activate([
            previousMonthLabel.topAnchor.constraint(equalTo: incomeCard.bottomAnchor, constant: 32),
            previousMonthLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            previousExpenseCard.topAnchor.constraint(equalTo: previousMonthLabel.bottomAnchor, constant: 12),
            previousExpenseCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previousExpenseCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previousExpenseCard.heightAnchor.constraint(equalToConstant: 80),

            previousIncomeCard.topAnchor.constraint(equalTo: previousExpenseCard.bottomAnchor, constant: 12),
            previousIncomeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previousIncomeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previousIncomeCard.heightAnchor.constraint(equalToConstant: 80)
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
            expenseButton.topAnchor.constraint(equalTo: previousIncomeCard.bottomAnchor, constant: 32),
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

        expenseCard.setValue(formatter.string(from: NSNumber(value: viewModel.currentMonthExpenses)) ?? "$0")
        expenseCard.setSubtitle("\(viewModel.currentMonthExpensesCount) transactions")

        incomeCard.setValue(formatter.string(from: NSNumber(value: viewModel.currentMonthIncomes)) ?? "$0")
        incomeCard.setSubtitle("\(viewModel.currentMonthIncomesCount) transactions")

        previousExpenseCard.setValue(formatter.string(from: NSNumber(value: viewModel.previousMonthExpenses)) ?? "$0")
        previousIncomeCard.setValue(formatter.string(from: NSNumber(value: viewModel.previousMonthIncomes)) ?? "$0")
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
}

class DashboardCardView: UIView {
    private let titleLabel = UILabel()
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