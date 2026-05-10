//
//  SetupCompleteViewController.swift
//  Notra
//

import UIKit

class SetupCompleteViewController: UIViewController {

    private let titleLabel = UILabel()
    private let pageTitleLabel = UILabel()
    private let continueLaterButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background
        title = "Setup Complete"
        navigationController?.navigationBar.prefersLargeTitles = true
        AppTheme.styleNavigationBar(navigationController!.navigationBar)

        titleLabel.text = "Setup Complete"
        titleLabel.font = AppTheme.Fonts.headingLarge
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let selectedTitle = UserDefaultsManager.shared.selectedPageTitle ?? "Unknown"
        pageTitleLabel.text = "Selected: \(selectedTitle)"
        pageTitleLabel.font = AppTheme.Fonts.body
        pageTitleLabel.textColor = AppTheme.Colors.textSecondary
        pageTitleLabel.textAlignment = .center
        pageTitleLabel.numberOfLines = 0
        pageTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageTitleLabel)

        AppTheme.applyPrimaryButtonStyle(to: continueLaterButton)
        continueLaterButton.setTitle("Continue to Dashboard", for: .normal)
        continueLaterButton.translatesAutoresizingMaskIntoConstraints = false
        continueLaterButton.addTarget(self, action: #selector(continueLaterButtonTapped), for: .touchUpInside)
        view.addSubview(continueLaterButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            pageTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            pageTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            pageTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            continueLaterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueLaterButton.topAnchor.constraint(equalTo: pageTitleLabel.bottomAnchor, constant: 60),
            continueLaterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            continueLaterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            continueLaterButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    @objc private func continueLaterButtonTapped() {
        guard let token = UserDefaultsManager.shared.notionToken else {
            let alert = UIAlertController(title: "Error", message: "No token found", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let dashboardVC = DashboardViewController(token: token)
        navigationController?.setViewControllers([dashboardVC], animated: true)
    }
}