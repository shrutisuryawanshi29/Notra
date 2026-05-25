//
//  ToastView.swift
//  Notra
//

import UIKit

class ToastView: UIView {

    private let label = UILabel()
    private let checkmarkImageView = UIImageView()
    private let padding: CGFloat = 16
    private let horizontalPadding: CGFloat = 20

    init(message: String) {
        super.init(frame: .zero)
        setupView(message: message)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView(message: String) {
        backgroundColor = AppTheme.Colors.cardBackground
        layer.cornerRadius = AppTheme.CornerRadius.medium
        layer.shadowColor = AppTheme.activePalette.shadow.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        if AppTheme.currentMode == .dark {
            layer.borderWidth = 1
            layer.borderColor = AppTheme.Colors.border.cgColor
        }

        translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let checkImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        checkmarkImageView.image = checkImage
        checkmarkImageView.tintColor = AppTheme.Colors.income
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkImageView)

        label.text = message
        label.font = AppTheme.Fonts.bodyBold
        label.textColor = AppTheme.Colors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            checkmarkImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            checkmarkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: checkmarkImageView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding),
            label.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ])
    }

    func show(in parentView: UIView, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        parentView.addSubview(self)

        let bottomOffset: CGFloat = parentView.safeAreaInsets.bottom > 0 ? 80 : 100

        let bottomConstraint = bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.bottomAnchor, constant: 100)
        bottomConstraint.isActive = true

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(greaterThanOrEqualTo: parentView.leadingAnchor, constant: 20),
            trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -20),
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor)
        ])

        parentView.layoutIfNeeded()

        bottomConstraint.constant = -bottomOffset
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            parentView.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            bottomConstraint.constant = 100
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                parentView.layoutIfNeeded()
            } completion: { _ in
                self.removeFromSuperview()
                completion?()
            }
        }
    }
}
