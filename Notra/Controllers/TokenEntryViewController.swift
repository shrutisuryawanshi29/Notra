//
//  TokenEntryViewController.swift
//  Notra
//

import UIKit

class TokenEntryViewController: UIViewController {

    private let viewModel = TokenEntryViewModel()
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tokenTextField = UITextField()
    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Notra"
        navigationController?.navigationBar.prefersLargeTitles = false

        titleLabel.text = "Notra"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel.text = "Connect your Notion workspace"
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        tokenTextField.placeholder = "Notion Integration Token"
        tokenTextField.borderStyle = .roundedRect
        tokenTextField.autocapitalizationType = .none
        tokenTextField.autocorrectionType = .no
        tokenTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenTextField)

        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        continueButton.backgroundColor = .systemBlue
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 10
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            tokenTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46),
            tokenTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46),
            tokenTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 60),
            tokenTextField.heightAnchor.constraint(equalToConstant: 44),

            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.topAnchor.constraint(equalTo: tokenTextField.bottomAnchor, constant: 46),
            continueButton.widthAnchor.constraint(equalToConstant: 200),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
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
