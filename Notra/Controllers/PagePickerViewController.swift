//
//  PagePickerViewController.swift
//  Notra
//

import UIKit

class PagePickerViewController: UIViewController {

    private let viewModel = PagePickerViewModel()
    private var pages: [NotionPage] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
        fetchPages()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Select Notion Page"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PageCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.backgroundColor = .systemBlue
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 8
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46),

            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16),
            retryButton.widthAnchor.constraint(equalToConstant: 100),
            retryButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupViewModel() {
        viewModel.delegate = self
    }

    private func fetchPages() {
        viewModel.fetchPages()
    }

    @objc private func retryButtonTapped() {
        fetchPages()
    }
}

extension PagePickerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PageCell", for: indexPath)
        let page = pages[indexPath.row]
        cell.textLabel?.text = page.title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.selectPage(at: indexPath.row)
        let roleAssignmentVC = DatabaseRoleAssignmentViewController()
        navigationController?.pushViewController(roleAssignmentVC, animated: true)
    }
}

extension PagePickerViewController: PagePickerViewModelDelegate {
    func pagePickerDidStartLoading() {
        activityIndicator.startAnimating()
        tableView.isHidden = true
        errorLabel.isHidden = true
        retryButton.isHidden = true
    }

    func pagePickerDidFinishLoading(pages: [NotionPage]) {
        self.pages = pages
        activityIndicator.stopAnimating()
        tableView.isHidden = false
        errorLabel.isHidden = true
        retryButton.isHidden = true
        tableView.reloadData()
    }

    func pagePickerDidFail(_ error: String) {
        activityIndicator.stopAnimating()
        tableView.isHidden = true
        errorLabel.text = error
        errorLabel.isHidden = false
        retryButton.isHidden = false
    }
}