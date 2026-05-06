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
        view.backgroundColor = .systemBackground
        title = "Setup Complete"

        titleLabel.text = "Setup Complete"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let selectedTitle = UserDefaultsManager.shared.selectedPageTitle ?? "Unknown"
        pageTitleLabel.text = "Selected: \(selectedTitle)"
        pageTitleLabel.font = .preferredFont(forTextStyle: .body)
        pageTitleLabel.textColor = .secondaryLabel
        pageTitleLabel.textAlignment = .center
        pageTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageTitleLabel)

        continueLaterButton.setTitle("Continue Later", for: .normal)
        continueLaterButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        continueLaterButton.backgroundColor = .systemBlue
        continueLaterButton.setTitleColor(.white, for: .normal)
        continueLaterButton.layer.cornerRadius = 10
        continueLaterButton.translatesAutoresizingMaskIntoConstraints = false
        continueLaterButton.addTarget(self, action: #selector(continueLaterButtonTapped), for: .touchUpInside)
        view.addSubview(continueLaterButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 150),

            pageTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 19),
            pageTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46),
            pageTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46),

            continueLaterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueLaterButton.topAnchor.constraint(equalTo: pageTitleLabel.bottomAnchor, constant: 99),
            continueLaterButton.widthAnchor.constraint(equalToConstant: 200),
            continueLaterButton.heightAnchor.constraint(equalToConstant: 50)
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