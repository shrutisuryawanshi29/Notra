//
//  PagePickerViewController.swift
//  Notra
//

import UIKit

class PagePickerViewController: UIViewController {

    private let viewModel = PagePickerViewModel()
    private var pages: [NotionPage] = []

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let logoContainerView = UIView()
    private let logoIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let cardView = UIView()
    private let cardTitleLabel = UILabel()
    private let helpButton = UIButton(type: .system)

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        return tv
    }()

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
        view.backgroundColor = AppTheme.Colors.background
        title = "Select Page"
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

        logoIconView.image = UIImage(systemName: "doc.text.fill")
        logoIconView.tintColor = AppTheme.Colors.primaryBrown
        logoIconView.contentMode = .scaleAspectFit
        logoIconView.translatesAutoresizingMaskIntoConstraints = false
        logoContainerView.addSubview(logoIconView)

        titleLabel.text = "Choose a Page"
        titleLabel.font = AppTheme.Fonts.headingLarge
        titleLabel.textColor = AppTheme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.text = "Select the Notion page containing your expense and income databases"
        subtitleLabel.font = AppTheme.Fonts.body
        subtitleLabel.textColor = AppTheme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            logoContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
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

        cardTitleLabel.text = "Available Pages"
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

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PageCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppTheme.Colors.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.backgroundColor = AppTheme.Colors.cardBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        cardView.addSubview(activityIndicator)

        errorLabel.font = AppTheme.Fonts.body
        errorLabel.textColor = AppTheme.Colors.textSecondary
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        cardView.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cardTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            helpButton.centerYAnchor.constraint(equalTo: cardTitleLabel.centerYAnchor),
            helpButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            errorLabel.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 40),
            errorLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            errorLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
    }

    private func setupButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Retry"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = AppTheme.Colors.buttonSurface
        config.baseForegroundColor = AppTheme.Colors.buttonContent
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Fonts.buttonMedium
            return outgoing
        }

        retryButton.configuration = config
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        contentView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 140),
            retryButton.heightAnchor.constraint(equalToConstant: 48),
            retryButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    @objc private func showHelpTapped() {
        let alert = UIAlertController(
            title: "How Pages Work",
            message: """
            Select a Notion page that contains your expense and income databases.

            Notra will scan the selected page to find any databases you want to track.

            Tip: Make sure your integration has access to the page.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
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
        cell.textLabel?.font = AppTheme.Fonts.body
        cell.textLabel?.textColor = AppTheme.Colors.textPrimary
        cell.accessoryType = .disclosureIndicator
        cell.accessoryView?.tintColor = AppTheme.Colors.primaryBrown
        cell.backgroundColor = AppTheme.Colors.cardBackground
        cell.selectionStyle = .default
        let selectedView = UIView()
        selectedView.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        cell.selectedBackgroundView = selectedView
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
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

        if pages.isEmpty {
            tableView.isHidden = true
            errorLabel.text = "No pages found.\n\nMake sure your Notion workspace has accessible pages."
            errorLabel.isHidden = false
            retryButton.isHidden = false
        } else {
            tableView.isHidden = false
            errorLabel.isHidden = true
            retryButton.isHidden = true
            tableView.reloadData()
        }
    }

    func pagePickerDidFail(_ error: String) {
        activityIndicator.stopAnimating()
        tableView.isHidden = true

        let friendlyMessage: String
        if error.lowercased().contains("unauthorized") || error.lowercased().contains("invalid") {
            friendlyMessage = "Couldn't access your Notion.\n\nPlease check your token and try again."
        } else if error.lowercased().contains("network") {
            friendlyMessage = "Having trouble connecting to Notion.\n\nCheck your internet connection."
        } else {
            friendlyMessage = "Something went wrong.\n\nPlease try again."
        }

        errorLabel.text = friendlyMessage
        errorLabel.isHidden = false
        retryButton.isHidden = false
    }
}
