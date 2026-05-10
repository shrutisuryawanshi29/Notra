//
//  TokenEntryViewController.swift
//  Notra
//

import UIKit

class TokenEntryViewController: UIViewController {

    private let viewModel = TokenEntryViewModel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let logoContainerView = UIView()
    private let logoIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let cardView = UIView()
    private let cardTitleLabel = UILabel()
    private let helpButton = UIButton(type: .system)
    private let tokenTextField = UITextField()
    private let hintLabel = UILabel()

    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background
        title = "Welcome"
        navigationController?.navigationBar.prefersLargeTitles = false
        AppTheme.styleNavigationBar(navigationController!.navigationBar)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        setupScrollView()
        setupHeader()
        setupCard()
        setupButton()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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

    private func setupHeader() {
        logoContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoContainerView)

        logoIconView.image = UIImage(systemName: "wallet.pass.fill")
        logoIconView.tintColor = AppTheme.Colors.primaryBrown
        logoIconView.contentMode = .scaleAspectFit
        logoIconView.translatesAutoresizingMaskIntoConstraints = false
        logoContainerView.addSubview(logoIconView)

        titleLabel.text = "Welcome to Notra"
        titleLabel.font = AppTheme.Fonts.headingLarge
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.text = "Connect your Notion workspace to start tracking your finances"
        subtitleLabel.font = AppTheme.Fonts.body
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            logoContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoContainerView.widthAnchor.constraint(equalToConstant: 80),
            logoContainerView.heightAnchor.constraint(equalToConstant: 80),

            logoIconView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            logoIconView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            logoIconView.widthAnchor.constraint(equalToConstant: 50),
            logoIconView.heightAnchor.constraint(equalToConstant: 50),

            logoContainerView.widthAnchor.constraint(equalToConstant: 80),
            logoContainerView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: logoContainerView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32)
        ])
    }

    private func setupCard() {
        AppTheme.applyCardStyle(to: cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        cardTitleLabel.text = "Notion Integration Token"
        cardTitleLabel.font = AppTheme.Fonts.captionBold
        cardTitleLabel.textColor = AppTheme.Colors.textPrimary
        cardTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardTitleLabel)

        let helpConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        helpButton.setImage(UIImage(systemName: "questionmark.circle", withConfiguration: helpConfig), for: .normal)
        helpButton.tintColor = AppTheme.Colors.textMuted
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.addTarget(self, action: #selector(showHelpTapped), for: .touchUpInside)
        cardView.addSubview(helpButton)

        tokenTextField.placeholder = "Enter your Notion integration token"
        tokenTextField.font = AppTheme.Fonts.body
        tokenTextField.textColor = AppTheme.Colors.textPrimary
        tokenTextField.borderStyle = .none
        tokenTextField.autocapitalizationType = .none
        tokenTextField.autocorrectionType = .no
        tokenTextField.returnKeyType = .done
        tokenTextField.delegate = self
        tokenTextField.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        tokenTextField.layer.cornerRadius = AppTheme.CornerRadius.medium
        tokenTextField.layer.borderWidth = 1
        tokenTextField.layer.borderColor = AppTheme.Colors.border.cgColor
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tokenTextField.leftView = paddingView
        tokenTextField.leftViewMode = .always
        tokenTextField.rightView = paddingView
        tokenTextField.rightViewMode = .always
        tokenTextField.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(tokenTextField)

        hintLabel.text = "Get your token from notion.so/my-integrations"
        hintLabel.font = AppTheme.Fonts.small
        hintLabel.textColor = AppTheme.Colors.textMuted
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cardTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            helpButton.centerYAnchor.constraint(equalTo: cardTitleLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            tokenTextField.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 12),
            tokenTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            tokenTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            tokenTextField.heightAnchor.constraint(equalToConstant: 48),

            hintLabel.topAnchor.constraint(equalTo: tokenTextField.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            hintLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    @objc private func showHelpTapped() {
        let alert = UIAlertController(
            title: "How to Get Your Token",
            message: """
            1. Go to notion.so/my-integrations
            2. Click "Create new integration"
            3. Give it a name (e.g., Notra)
            4. Select "Internal" integration
            5. Click "Submit"
            6. Copy the "Internal Integration Secret" token
            7. Paste it above and continue

            Note: Your token typically starts with "secret_" but may vary.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    private func setupButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Continue"
        config.image = UIImage(systemName: "arrow.right")
        config.imagePadding = 8
        config.imagePlacement = .trailing
        config.baseBackgroundColor = AppTheme.Colors.primaryBrown
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Fonts.buttonLarge
            return outgoing
        }

        continueButton.configuration = config
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        contentView.addSubview(continueButton)

        NSLayoutConstraint.activate([
            continueButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 32),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func setupViewModel() {
        viewModel.delegate = self
    }

    @objc private func continueButtonTapped() {
        guard let token = tokenTextField.text else { return }
        viewModel.validateAndSave(token: token)
    }
}

extension TokenEntryViewController: TokenEntryViewModelDelegate {
    func tokenEntryDidSave() {
        let pagePicker = PagePickerViewController()
        navigationController?.pushViewController(pagePicker, animated: true)
    }

    func tokenEntryDidFailValidation(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension TokenEntryViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        continueButtonTapped()
        return true
    }
}
