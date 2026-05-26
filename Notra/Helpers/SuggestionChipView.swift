import UIKit

final class SuggestionChipView: UIView {

    private let label = UILabel()
    var onTap: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        setupUI(title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(title: String) {
        backgroundColor = AppTheme.Colors.accent.withAlphaComponent(0.12)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = AppTheme.Colors.border.withAlphaComponent(0.3).cgColor

        label.text = title
        label.font = AppTheme.Fonts.smallMedium
        label.textColor = AppTheme.Colors.accent
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @objc private func didTap() {
        onTap?()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        alpha = 0.6
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        alpha = 1.0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        alpha = 1.0
    }
}
