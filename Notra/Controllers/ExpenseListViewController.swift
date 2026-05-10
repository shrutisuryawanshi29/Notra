//
//  ExpenseListViewController.swift
//  Notra
//

import UIKit

class ExpenseListViewController: UIViewController {

    private let viewModel = ExpenseListViewModel()
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = AppTheme.Colors.background
        return tv
    }()
    private let emptyView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.Colors.background
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.delegate = self
        viewModel.loadFromCache()
    }

    private func setupUI() {
        title = "Expenses"
        view.backgroundColor = AppTheme.Colors.background

        navigationController?.navigationBar.prefersLargeTitles = true

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FinanceCell.self, forCellReuseIdentifier: "FinanceCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        setupEmptyState()

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func setupEmptyState() {
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        let iconView = UIImageView(image: UIImage(systemName: "tray"))
        iconView.tintColor = AppTheme.Colors.textTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(iconView)

        let label = UILabel()
        label.text = "No expenses for this month"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = AppTheme.Colors.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "Transactions sync from your Notion databases. Select a different month from Dashboard to view more data."
        sublabel.font = .systemFont(ofSize: 14)
        sublabel.textColor = AppTheme.Colors.textTertiary
        sublabel.textAlignment = .center
        sublabel.numberOfLines = 0
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(sublabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: emptyView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),

            sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            sublabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            sublabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
            sublabel.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor)
        ])
    }
}

extension ExpenseListViewController: ExpenseListViewModelDelegate {
    func didLoadExpenses() {
        tableView.reloadData()
        emptyView.isHidden = viewModel.hasData
        tableView.isHidden = !viewModel.hasData
    }
}

extension ExpenseListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].transactions.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionData = viewModel.sections[section]
        return sectionData.displayDate
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FinanceCell", for: indexPath) as! FinanceCell
        if let transaction = viewModel.getTransaction(at: indexPath) {
            cell.configure(expense: transaction)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}