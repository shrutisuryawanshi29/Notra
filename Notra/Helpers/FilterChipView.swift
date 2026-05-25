import UIKit

class FilterChipView: UIView {

    private let label = UILabel()
    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        b.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    var onRemove: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        setupUI(text: text)
    }

    private func setupUI(text: String) {
        backgroundColor = AppTheme.Colors.cardBackgroundAlt
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = AppTheme.Colors.border.cgColor

        layer.shadowColor = AppTheme.activePalette.shadow.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 3
        layer.masksToBounds = false

        label.text = text
        label.font = AppTheme.Fonts.caption
        label.textColor = AppTheme.Colors.textPrimary
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        closeButton.tintColor = AppTheme.Colors.textMuted
        closeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 14),
            closeButton.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
