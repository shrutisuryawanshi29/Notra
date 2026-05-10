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
        backgroundColor = AppTheme.Colors.cardBackground
        accessoryType = .disclosureIndicator

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        containerView.layer.cornerRadius = AppTheme.CornerRadius.medium
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = AppTheme.Fonts.bodyBold
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        categoryLabel.font = AppTheme.Fonts.smallMedium
        categoryLabel.textColor = AppTheme.Colors.textSecondary
        categoryLabel.textAlignment = .center
        categoryLabel.layer.cornerRadius = AppTheme.CornerRadius.pill
        categoryLabel.layer.masksToBounds = true
        categoryLabel.backgroundColor = AppTheme.Colors.secondaryTan
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(categoryLabel)

        amountLabel.font = AppTheme.Fonts.bodyBold
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(amountLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconContainer.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),

            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            categoryLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            categoryLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            amountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            amountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
    }

    func configure(expense: NormalizedTransaction) {
        titleLabel.text = expense.title

        let category = expense.category ?? "Uncategorized"
        categoryLabel.text = "  \(category)  "

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        amountLabel.text = formatter.string(from: NSNumber(value: expense.amount))
        amountLabel.textColor = AppTheme.Colors.expense

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        iconContainer.backgroundColor = AppTheme.Colors.expenseLight
        iconImageView.image = UIImage(systemName: "arrow.up.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.expense
    }

    func configure(income: NormalizedTransaction) {
        titleLabel.text = income.title

        let source = income.category ?? "Income"
        categoryLabel.text = "  \(source)  "

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        amountLabel.text = formatter.string(from: NSNumber(value: income.amount))
        amountLabel.textColor = AppTheme.Colors.income

        containerView.backgroundColor = AppTheme.Colors.cardBackground
        iconContainer.backgroundColor = AppTheme.Colors.incomeLight
        iconImageView.image = UIImage(systemName: "arrow.down.circle.fill")
        iconImageView.tintColor = AppTheme.Colors.income
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) {
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.containerView.alpha = highlighted ? 0.8 : 1.0
        }
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