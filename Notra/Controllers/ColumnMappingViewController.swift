//
//  ColumnMappingViewController.swift
//  Notra
//

import UIKit

class ColumnMappingViewController: UIViewController {

    private let viewModel: ColumnMappingViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var selectedCategoryColumn: String?
    private var categoryValues: [CategoryValue] = []

    init(database: DiscoveredDatabase, role: DatabaseRole) {
        self.viewModel = ColumnMappingViewModel(database: database, role: role)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.delegate = self
        viewModel.autoSuggestMapping()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Map Columns - \(viewModel.role.displayName)"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MappingCell.self, forCellReuseIdentifier: "MappingCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save & Continue", for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalToConstant: 200),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func saveButtonTapped() {
        viewModel.saveAndParseCategories()
    }

    private func showColumnPicker(for field: ColumnField) {
        let alert = UIAlertController(title: field.rawValue, message: "Select column", preferredStyle: .actionSheet)

        for property in viewModel.propertyNames {
            alert.addAction(UIAlertAction(title: property, style: .default) { [weak self] _ in
                self?.viewModel.setMapping(for: field, columnName: property)
                self?.tableView.reloadData()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension ColumnMappingViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ColumnField.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MappingCell", for: indexPath) as! MappingCell
        let field = ColumnField.allCases[indexPath.row]
        let selectedColumn = viewModel.getMapping(for: field)
        cell.configure(field: field, selectedColumn: selectedColumn)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let field = ColumnField.allCases[indexPath.row]
        showColumnPicker(for: field)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Tap a row to select the corresponding Notion column. Auto-suggestions are shown."
    }
}

extension ColumnMappingViewController: ColumnMappingViewModelDelegate {
    func columnMappingDidStartLoading() {
        activityIndicator.startAnimating()
        tableView.isHidden = true
    }

    func columnMappingDidFinishLoading(mapping: ColumnMapping, categories: [CategoryValue]) {
        activityIndicator.stopAnimating()
        tableView.isHidden = false

        if !categories.isEmpty {
            print("Detected Categories:")
            for cat in categories {
                print("  - \(cat.name) (\(cat.sourceType))")
            }
        }

        navigateToNextDatabase()
    }

    func columnMappingDidFail(_ error: String) {
        activityIndicator.stopAnimating()
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func navigateToNextDatabase() {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        
        let pendingExpense = mappings.values.first { $0.role == .expense && $0.columnMapping == nil }
        let pendingIncome = mappings.values.first { $0.role == .income && $0.columnMapping == nil }

        if let pending = pendingExpense {
            showColumnMappingForDatabase(pending)
        } else if let pending = pendingIncome {
            showColumnMappingForDatabase(pending)
        } else {
            showCompletionAlert()
        }
    }

    private func showColumnMappingForDatabase(_ mappingData: DatabaseMappingData) {
        guard let token = UserDefaultsManager.shared.notionToken else {
            showError("No token")
            return
        }

        activityIndicator.startAnimating()
        
        let baseURL = AppConstants.API.notionBaseURL
        guard let url = URL(string: "\(baseURL)/databases/\(mappingData.databaseId)") else {
            showError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConstants.API.notionVersion, forHTTPHeaderField: "Notion-Version")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                if error != nil {
                    self?.showError("Failed to fetch database schema")
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let properties = json["properties"] as? [String: Any] else {
                    self?.showError("Failed to parse schema")
                    return
                }
                
                var dbProperties: [String: DiscoveredDatabase.DatabaseProperty] = [:]
                for (propName, propValue) in properties {
                    if let prop = propValue as? [String: Any], let propType = prop["type"] as? String {
                        dbProperties[propName] = DiscoveredDatabase.DatabaseProperty(name: propName, type: propType)
                    }
                }
                
                let db = DiscoveredDatabase(
                    id: mappingData.databaseId,
                    title: mappingData.databaseTitle,
                    parentPageId: "",
                    properties: dbProperties,
                    assignedRole: mappingData.role
                )
                
                let columnVC = ColumnMappingViewController(database: db, role: mappingData.role)
                self?.navigationController?.pushViewController(columnVC, animated: true)
            }
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showCompletionAlert() {
        let mappings = ColumnMappingService.shared.loadDatabaseMappings()
        let count = mappings.count
        let message = "\(count) database(s) configured. Ready for Phase 3."
        
        let alert = UIAlertController(title: "Setup Complete", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Mapping Cell

class MappingCell: UITableViewCell {
    private let fieldLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        fieldLabel.font = .preferredFont(forTextStyle: .headline)
        fieldLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fieldLabel)

        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            fieldLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            fieldLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fieldLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            valueLabel.topAnchor.constraint(equalTo: fieldLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    func configure(field: ColumnField, selectedColumn: String?) {
        fieldLabel.text = field.rawValue
        valueLabel.text = selectedColumn ?? "Not selected"
        accessoryType = .disclosureIndicator
    }
}