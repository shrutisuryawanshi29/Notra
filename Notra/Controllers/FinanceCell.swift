//
//  FinanceCell.swift
//  Notra
//

import UIKit

class FinanceCell: UITableViewCell {
    private let containerView = UIView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let categoryContainer = UIView()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()
    private let chevronView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        containerView.layer.cornerRadius = AppTheme.CornerRadius.medium
        containerView.layer.borderWidth = AppTheme.currentMode == .dark ? 1 : 0
        containerView.layer.borderColor = AppTheme.Colors.border.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        iconContainer.backgroundColor = AppTheme.Colors.expenseLight
        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppTheme.Colors.expense
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = AppTheme.Fonts.bodyBold
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        categoryContainer.backgroundColor = AppTheme.Colors.secondaryTan
        categoryContainer.layer.cornerRadius = 12
        categoryContainer.clipsToBounds = true
        categoryContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(categoryContainer)

        categoryLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        categoryLabel.textColor = .white
        categoryLabel.textAlignment = .center
        categoryLabel.numberOfLines = 1
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryContainer.addSubview(categoryLabel)

        amountLabel.font = AppTheme.Fonts.bodyBold
        amountLabel.textColor = AppTheme.Colors.expense
        amountLabel.textAlignment = .right
        amountLabel.numberOfLines = 0
        amountLabel.lineBreakMode = .byWordWrapping
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(amountLabel)

        chevronView.image = UIImage(systemName: "chevron.right")
        chevronView.tintColor = AppTheme.Colors.textMuted
        chevronView.contentMode = .scaleAspectFit
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chevronView)

        let amountWidthConstraint = amountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 130)
        amountWidthConstraint.priority = .required

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -12),

            categoryContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            categoryContainer.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            categoryContainer.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -12),
            categoryContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),

            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 4),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -4),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 12),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -12),

            chevronView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14),

            amountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            amountWidthConstraint
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

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        iconContainer.backgroundColor = AppTheme.Colors.expenseLight
        iconImageView.image = UIImage(systemName: "arrow.up.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.expense
        categoryContainer.backgroundColor = AppTheme.Colors.secondaryTan
        categoryLabel.textColor = .white
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

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        iconContainer.backgroundColor = AppTheme.Colors.incomeLight
        iconImageView.image = UIImage(systemName: "arrow.down.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.income
        categoryContainer.backgroundColor = AppTheme.Colors.secondaryTan
        categoryLabel.textColor = .white
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        categoryLabel.text = nil
        amountLabel.text = nil
        containerView.transform = .identity
        containerView.alpha = 1.0
    }
}