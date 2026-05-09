//
//  FinanceCell.swift
//  Notra
//

import UIKit

class FinanceCell: UITableViewCell {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        categoryLabel.font = .systemFont(ofSize: 13)
        categoryLabel.textColor = AppTheme.Colors.textSecondary
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoryLabel)

        amountLabel.font = .systemFont(ofSize: 16, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(amountLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            categoryLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }

    func configure(expense: NormalizedTransaction) {
        titleLabel.text = expense.title

        let category = expense.category ?? "Uncategorized"
        categoryLabel.text = category

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        amountLabel.text = formatter.string(from: NSNumber(value: expense.amount))
        amountLabel.textColor = AppTheme.Colors.expense

        iconContainer.backgroundColor = AppTheme.Colors.expense.withAlphaComponent(0.15)
        iconImageView.image = UIImage(systemName: "arrow.up.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.expense
    }

    func configure(income: NormalizedTransaction) {
        titleLabel.text = income.title

        let source = income.category ?? "Income"
        categoryLabel.text = source

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        amountLabel.text = formatter.string(from: NSNumber(value: income.amount))
        amountLabel.textColor = AppTheme.Colors.income

        iconContainer.backgroundColor = AppTheme.Colors.income.withAlphaComponent(0.15)
        iconImageView.image = UIImage(systemName: "arrow.down.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.income
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        categoryLabel.text = nil
        amountLabel.text = nil
    }
}