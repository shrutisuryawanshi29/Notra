import UIKit

class IncomeListViewController: UIViewController {

    private let viewModel = IncomeListViewModel()
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = AppTheme.Colors.background
        return tv
    }()
    private let emptyStateView = EmptyStateView()
    private let filterButton = UIButton(type: .system)
    private var isLoadingSchemas = false
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.searchBarStyle = .minimal
        sb.placeholder = "Search income"
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()
    private let searchBarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = AppTheme.Colors.cardBackground
        v.layer.cornerRadius = AppTheme.CornerRadius.large
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let chipsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: AppTheme.Spacing.screenPadding)
        return sv
    }()
    private let chipsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = AppTheme.Spacing.small
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private var chipsHeightConstraint: NSLayoutConstraint!
    private let summaryView: UIView = {
        let v = UIView()
        v.backgroundColor = AppTheme.Colors.cardBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let summaryLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = AppTheme.Fonts.captionBold
        lbl.textColor = AppTheme.Colors.primaryBrown
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.delegate = self
        viewModel.loadFromCache()
    }

    private func setupUI() {
        title = "Income"
        view.backgroundColor = AppTheme.Colors.background

        AppTheme.styleNavigationBar(navigationController!.navigationBar)

        setupFilterButton()
        setupSearchBar()
        setupChipsContainer()
        setupSummaryView()
        setupTableView()
        setupEmptyState()
    }

    private func setupFilterButton() {
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButton.tintColor = AppTheme.Colors.primaryBrown
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        let barButton = UIBarButtonItem(customView: filterButton)
        navigationItem.rightBarButtonItem = barButton
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.searchTextField.backgroundColor = AppTheme.Colors.cardBackground
        searchBar.searchTextField.textColor = AppTheme.Colors.textPrimary
        searchBar.searchTextField.tintColor = AppTheme.Colors.primaryBrown
        searchBar.searchTextField.leftView?.tintColor = AppTheme.Colors.textMuted
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search income",
            attributes: [.foregroundColor: AppTheme.Colors.textMuted]
        )

        view.addSubview(searchBarContainer)
        searchBarContainer.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.small),
            searchBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.screenPadding),
            searchBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.screenPadding),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 44),

            searchBar.topAnchor.constraint(equalTo: searchBarContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor, constant: -4),
            searchBar.bottomAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
        ])

        AppTheme.Shadow.applySoft(to: searchBarContainer)
    }

    private func setupChipsContainer() {
        chipsScrollView.addSubview(chipsStackView)
        view.addSubview(chipsScrollView)

        chipsHeightConstraint = chipsScrollView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            chipsScrollView.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor, constant: 4),
            chipsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.screenPadding),
            chipsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipsHeightConstraint,

            chipsStackView.topAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.topAnchor),
            chipsStackView.leadingAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.leadingAnchor),
            chipsStackView.trailingAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.trailingAnchor),
            chipsStackView.bottomAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.bottomAnchor),
            chipsStackView.heightAnchor.constraint(equalTo: chipsScrollView.frameLayoutGuide.heightAnchor),
        ])

        chipsScrollView.isHidden = true
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FinanceCell.self, forCellReuseIdentifier: "FinanceCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: chipsScrollView.bottomAnchor, constant: AppTheme.Spacing.small),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: summaryView.topAnchor),
        ])
    }

    private func setupEmptyState() {
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        emptyStateView.configure(
            icon: "tray",
            title: "No income yet",
            message: "Income you add for this month will appear here."
        )

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func setupSummaryView() {
        let separator = UIView()
        separator.backgroundColor = AppTheme.Colors.textMuted.withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        summaryView.addSubview(separator)
        summaryView.addSubview(summaryLabel)
        view.addSubview(summaryView)

        NSLayoutConstraint.activate([
            summaryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            summaryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            summaryView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            summaryView.heightAnchor.constraint(equalToConstant: 44),

            separator.topAnchor.constraint(equalTo: summaryView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            summaryLabel.centerYAnchor.constraint(equalTo: summaryView.centerYAnchor),
            summaryLabel.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor, constant: -16)
        ])

        summaryView.isHidden = true
    }

    private func updateSummaryView() {
        if viewModel.hasActiveFilters, viewModel.hasData {
            let count = viewModel.sections.reduce(0) { $0 + $1.transactions.count }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            let totalStr = formatter.string(from: NSNumber(value: viewModel.totalAmount)) ?? "$0.00"
            summaryLabel.text = "Filtered Total: \(totalStr) · \(count) item\(count == 1 ? "" : "s")"
            summaryView.isHidden = false
        } else {
            summaryView.isHidden = true
        }
    }

    private func updateEmptyState() {
        if viewModel.isSearching && viewModel.hasActiveFilters {
            emptyStateView.configure(
                icon: "magnifyingglass",
                title: "No matches found",
                message: "Try clearing filters or changing your search.",
                actionTitle: "Clear Filters"
            )
            emptyStateView.onAction = { [weak self] in
                self?.clearFiltersTapped()
            }
        } else if viewModel.isSearching {
            emptyStateView.configure(
                icon: "magnifyingglass",
                title: "No results",
                message: "Try a different search term."
            )
            emptyStateView.onAction = nil
        } else if viewModel.hasActiveFilters {
            emptyStateView.configure(
                icon: "tray",
                title: "No matches found",
                message: "Try clearing filters or changing your search.",
                actionTitle: "Clear Filters"
            )
            emptyStateView.onAction = { [weak self] in
                self?.clearFiltersTapped()
            }
        } else {
            emptyStateView.configure(
                icon: "tray",
                title: "No income yet",
                message: "Income you add for this month will appear here."
            )
            emptyStateView.onAction = nil
        }
    }

    private func updateChips() {
        chipsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var hasChips = false

        for filter in viewModel.activeFilters {
            let chip = FilterChipView(text: filter.chipDisplayText)
            chip.onRemove = { [weak self] in
                self?.viewModel.removeFilter(byId: filter.id)
            }
            chipsStackView.addArrangedSubview(chip)
            hasChips = true
        }

        if let dr = viewModel.dateRange, dr.isActive {
            let chip = FilterChipView(text: "Date: \(dr.displayString)")
            chip.onRemove = { [weak self] in
                self?.viewModel.clearDateRange()
            }
            chipsStackView.addArrangedSubview(chip)
            hasChips = true
        }

        chipsScrollView.isHidden = !hasChips
        chipsHeightConstraint.constant = hasChips ? 36 : 0
        chipsScrollView.layoutIfNeeded()
    }

    private func updateFilterButton() {
        if viewModel.hasActiveFilters {
            filterButton.setImage(nil, for: .normal)
            filterButton.setTitle("Filters (\(viewModel.activeFilterCount))", for: .normal)
            filterButton.titleLabel?.font = AppTheme.Fonts.bodyMedium
            filterButton.sizeToFit()
        } else {
            filterButton.setTitle(nil, for: .normal)
            filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
            filterButton.sizeToFit()
        }
    }

    // MARK: - Actions

    @objc private func filterTapped() {
        let token = UserDefaultsManager.shared.notionToken ?? ""
        let dbIds = viewModel.databaseIds

        let (properties, selectOptions, relationOptions, needsSchemaFetch) = deriveFilterOptions()

        if needsSchemaFetch && !token.isEmpty && !isLoadingSchemas {
            isLoadingSchemas = true
            let group = DispatchGroup()
            for dbId in dbIds {
                if SessionCacheManager.shared.getDatabaseSchema(databaseId: dbId) == nil {
                    group.enter()
                    fetchAndCacheRelationTargetDbIds(databaseId: dbId, token: token) {
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.isLoadingSchemas = false
                let (updatedProperties, updatedSelectOptions, updatedRelationOptions, _) = self.deriveFilterOptions()
                self.presentFilterPanel(
                    properties: updatedProperties,
                    selectOptions: updatedSelectOptions,
                    relationOptions: updatedRelationOptions,
                    token: token,
                    dbIds: dbIds
                )
            }
        } else {
            presentFilterPanel(
                properties: properties,
                selectOptions: selectOptions,
                relationOptions: relationOptions,
                token: token,
                dbIds: dbIds
            )
        }
    }

    private func presentFilterPanel(
        properties: [(name: String, type: NotionPropertyType)],
        selectOptions: [String: [String]],
        relationOptions: [String: [(id: String, title: String)]],
        token: String,
        dbIds: [String]
    ) {
        let panel = FilterPanelViewController(
            databaseId: viewModel.databaseIds.first ?? "",
            databaseRole: .income,
            currentFilters: viewModel.activeFilters,
            currentDateRange: viewModel.dateRange,
            allProperties: properties,
            selectOptions: selectOptions,
            relationOptions: relationOptions,
            notionToken: token,
            databaseIds: dbIds
        )
        panel.delegate = self
        let nav = UINavigationController(rootViewController: panel)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func clearFiltersTapped() {
        viewModel.clearFilters()
        updateEmptyState()
        updateFilterButton()
        updateChips()
        updateSummaryView()
    }

    // MARK: - Schema & Relation Options

    private func fetchAndCacheRelationTargetDbIds(databaseId: String, token: String, completion: @escaping () -> Void) {
        NotionService.shared.fetchDatabaseSchema(databaseId: databaseId, token: token) { result in
            switch result {
            case .success(let properties):
                var propertySchema: [String: String] = [:]
                var relationMapping: [String: String] = [:]
                var selectOpts: [String: [String]] = [:]

                for (name, raw) in properties {
                    guard let dict = raw as? [String: Any], let type = dict["type"] as? String else { continue }
                    propertySchema[name] = type

                    if type == "relation" {
                        if let relationConfig = dict["relation"] as? [String: Any],
                           let targetDbId = (relationConfig["database_id"] as? String) ?? (relationConfig["data_source_id"] as? String) {
                            relationMapping[name] = targetDbId
                        }
                    }

                    if type == "select" || type == "status" {
                        let configKey = type == "status" ? "status" : "select"
                        if let config = dict[configKey] as? [String: Any],
                           let options = config["options"] as? [[String: Any]] {
                            selectOpts[name] = options.compactMap { $0["name"] as? String }
                        }
                    }

                    if type == "multi_select" {
                        if let config = dict["multi_select"] as? [String: Any],
                           let options = config["options"] as? [[String: Any]] {
                            selectOpts[name] = options.compactMap { $0["name"] as? String }
                        }
                    }
                }

                SessionCacheManager.shared.saveDatabaseSchema(databaseId: databaseId, schema: propertySchema)
                if !selectOpts.isEmpty {
                    SessionCacheManager.shared.saveSelectOptions(databaseId: databaseId, options: selectOpts)
                }
                if !relationMapping.isEmpty {
                    SessionCacheManager.shared.saveRelationTargetDbIds(databaseId: databaseId, mapping: relationMapping)
                }

            case .failure:
                #if DEBUG
                print("[IncomeFilter] Failed to fetch schema for DB: \(databaseId)")
                #endif
            }
            completion()
        }
    }

    private func deriveFilterOptions() -> (
        properties: [(name: String, type: NotionPropertyType)],
        selectOptions: [String: [String]],
        relationOptions: [String: [(id: String, title: String)]],
        needsSchemaFetch: Bool
    ) {
        var propertySet: [(String, NotionPropertyType)] = []
        var seenProps = Set<String>()
        var selectOpts: [String: Set<String>] = [:]
        var allDbIds = Set<String>()
        var needsFetch = false

        for tx in viewModel.allTransactions {
            allDbIds.insert(tx.databaseId)
            guard let raw = tx.rawProperties else { continue }
            for (name, prop) in raw {
                if !seenProps.contains(name), let typeStr = prop.type, let pType = NotionPropertyType.from(string: typeStr) {
                    if !NotionPropertyType.isReadOnly(typeStr) && pType != .url && pType != .email && pType != .phoneNumber {
                        seenProps.insert(name)
                        propertySet.append((name, pType))
                    }
                }
                if prop.type == "select" || prop.type == "status" {
                    if let optName = prop.select?.name {
                        selectOpts[name, default: []].insert(optName)
                    }
                }
                if prop.type == "multi_select" {
                    if let ms = prop.multiSelect {
                        for opt in ms {
                            if let optName = opt.name {
                                selectOpts[name, default: []].insert(optName)
                            }
                        }
                    }
                }
            }
        }

        let properties = propertySet.sorted { $0.0 < $1.0 }
        let selectOptions = selectOpts.mapValues { Array($0).sorted() }

        var relationOptions: [String: [(id: String, title: String)]] = [:]
        for (name, type) in propertySet where type == .relation {
            var targetDbId: String?
            for dbId in allDbIds {
                if let mapping = SessionCacheManager.shared.getAllRelationTargetDbIds(databaseId: dbId),
                   let tid = mapping[name] {
                    targetDbId = tid
                    break
                }
            }

            if let targetDbId = targetDbId {
                if let data = SessionCacheManager.shared.getRelationTargetData(databaseId: targetDbId) {
                    let opts = data.map { (id: $0.key, title: $0.value) }.sorted { $0.title < $1.title }
                    relationOptions[name] = opts
                } else {
                    relationOptions[name] = []
                }
            } else {
                needsFetch = true
                relationOptions[name] = []
            }
        }

        return (properties, selectOptions, relationOptions, needsFetch)
    }

    // MARK: - Detail, Edit & Delete

    private func showDetail(for transaction: NormalizedTransaction) {
        let detailVC = TransactionDetailViewController(transaction: transaction)
        detailVC.onEdit = { [weak self] tx in
            self?.editTransaction(tx)
        }
        detailVC.onDelete = { [weak self] tx in
            self?.deleteTransaction(tx)
        }
        let nav = UINavigationController(rootViewController: detailVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func editTransaction(_ transaction: NormalizedTransaction) {
        let editVC = AddTransactionViewController(
            prefillData: [:],
            initialRole: transaction.databaseRole,
            editingTransaction: transaction
        )
        editVC.onEditComplete = { [weak self] updatedTx, oldMonthKey in
            guard let self = self else { return }
            SessionCacheManager.shared.replaceIncome(updatedTx)
            self.viewModel.loadFromCache()
        }
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func deleteTransaction(_ transaction: NormalizedTransaction) {
        guard let token = UserDefaultsManager.shared.notionToken else { return }
        NotionService.shared.trashPage(pageId: transaction.id, token: token) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                SessionCacheManager.shared.removeIncome(byPageId: transaction.id)
                self.viewModel.loadFromCache()
            case .failure(let error):
                let alert = UIAlertController(
                    title: "Couldn't delete transaction.",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func deleteTransaction(_ transaction: NormalizedTransaction, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Transaction?",
            message: "This will move the transaction to trash in Notion.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self, let token = UserDefaultsManager.shared.notionToken else { return }
            NotionService.shared.trashPage(pageId: transaction.id, token: token) { result in
                switch result {
                case .success:
                    SessionCacheManager.shared.removeIncome(byPageId: transaction.id)
                    self.viewModel.loadFromCache()
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "Couldn't delete transaction.",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        })
        present(alert, animated: true)
    }
}

extension IncomeListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.setSearchQuery(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension IncomeListViewController: IncomeListViewModelDelegate {
    func didLoadIncomes() {
        tableView.reloadData()
        emptyStateView.isHidden = viewModel.hasData
        tableView.isHidden = !viewModel.hasData
        updateEmptyState()
        updateFilterButton()
        updateChips()
        updateSummaryView()
    }
}

extension IncomeListViewController: FilterPanelDelegate {
    func filterPanelDidApply(filters: [TransactionFilter], dateRange: DateRangeFilter?) {
        viewModel.applyFilters(filters: filters, dateRange: dateRange)
    }

    func filterPanelDidClear() {
        viewModel.clearFilters()
        updateChips()
        updateSummaryView()
    }

    func filterPanelDidDismiss() {
        // Filters stay active until user clears or changes them
    }
}

extension IncomeListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].transactions.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionData = viewModel.sections[section]
        return sectionData.displayDate
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.contentView.backgroundColor = AppTheme.Colors.background
        header.textLabel?.font = AppTheme.Fonts.captionBold
        header.textLabel?.textColor = AppTheme.Colors.textMuted
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 4
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FinanceCell", for: indexPath) as! FinanceCell
        if let transaction = viewModel.getTransaction(at: indexPath) {
            cell.configure(income: transaction)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let transaction = viewModel.getTransaction(at: indexPath) else { return }
        showDetail(for: transaction)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let transaction = viewModel.getTransaction(at: indexPath) else { return nil }

        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            self?.editTransaction(transaction)
            completion(true)
        }
        editAction.backgroundColor = AppTheme.Colors.secondaryBrown
        editAction.image = UIImage(systemName: "pencil")

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteTransaction(transaction, at: indexPath)
            completion(true)
        }
        deleteAction.backgroundColor = AppTheme.Colors.expense.withAlphaComponent(0.8)
        deleteAction.image = UIImage(systemName: "trash")

        let config = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}
