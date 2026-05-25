import UIKit

protocol FilterPanelDelegate: AnyObject {
    func filterPanelDidApply(filters: [TransactionFilter], dateRange: DateRangeFilter?)
    func filterPanelDidClear()
    func filterPanelDidDismiss()
}

final class FilterPanelViewController: UIViewController {

    private let viewModel: FilterPanelViewModel
    weak var delegate: FilterPanelDelegate?

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = AppTheme.Colors.background
        tv.separatorStyle = .none
        tv.sectionHeaderTopPadding = 0
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var isFromDatePickerExpanded = false
    private var isToDatePickerExpanded = false

    init(databaseId: String, databaseRole: DatabaseRole,
         currentFilters: [TransactionFilter], currentDateRange: DateRangeFilter?,
         allProperties: [(name: String, type: NotionPropertyType)],
         selectOptions: [String: [String]],
         relationOptions: [String: [(id: String, title: String)]],
         notionToken: String,
         databaseIds: [String]) {

        self.viewModel = FilterPanelViewModel(
            databaseId: databaseId,
            databaseRole: databaseRole,
            allProperties: allProperties,
            selectOptions: selectOptions,
            relationOptions: relationOptions,
            notionToken: notionToken,
            databaseIds: databaseIds
        )

        super.init(nibName: nil, bundle: nil)

        for filter in currentFilters {
            var row = FilterPanelViewModel.FilterRow(id: filter.id)
            row.selectedProperty = (filter.propertyName, filter.propertyType)
            row.selectedCondition = filter.condition
            if let val = filter.value {
                switch val {
                case .text(let v): row.textValue = v
                case .number(let v): row.numberValue = v
                case .numberRange(let a, _): row.numberValue = a
                case .date(let v): row.dateValue = v
                case .dateRange(let f, _): row.dateValue = f
                case .select(let v): row.selectValue = v
                case .multiSelect(let v): row.multiSelectValue = v
                case .relation(let id, let title): row.relationValue = (id, title)
                case .checkbox: break
                }
            }
            viewModel.filterRows.append(row)
        }
        if let dr = currentDateRange {
            viewModel.dateRange = dr
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.onRelationOptionsLoaded = { [weak self] propertyName, options in
            guard let self = self else { return }
            // Find the row index for this property and reload it
            if let rowIndex = self.viewModel.filterRows.firstIndex(where: {
                $0.selectedProperty?.name == propertyName
            }) {
                self.tableView.reloadRows(at: [IndexPath(row: rowIndex, section: Section.filters.rawValue)], with: .automatic)
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.Colors.background
        title = "Filters"

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.Colors.background
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.Colors.textPrimary, .font: AppTheme.Fonts.headingMedium]
        navAppearance.shadowColor = .clear
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.tintColor = AppTheme.Colors.primaryBrown

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAllTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .plain, target: self, action: #selector(applyTapped))

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FilterCell.self, forCellReuseIdentifier: "FilterCell")
        tableView.register(DateRangeCell.self, forCellReuseIdentifier: "DateRangeCell")
        tableView.register(DatePickerCell.self, forCellReuseIdentifier: "DatePickerCell")
        tableView.register(AddFilterCell.self, forCellReuseIdentifier: "AddFilterCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func clearAllTapped() {
        viewModel.clearAll()
        isFromDatePickerExpanded = false
        isToDatePickerExpanded = false
        tableView.reloadData()
    }

    @objc private func applyTapped() {
        let filters = viewModel.buildFilters()
        delegate?.filterPanelDidApply(filters: filters, dateRange: viewModel.dateRange.isActive ? viewModel.dateRange : nil)
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            delegate?.filterPanelDidDismiss()
        }
    }

    private func propertyForRow(_ row: Int) -> (name: String, type: NotionPropertyType)? {
        guard row < viewModel.filterRows.count else { return nil }
        return viewModel.filterRows[row].selectedProperty
    }

    private func conditionsForRow(_ row: Int) -> [FilterCondition] {
        guard let prop = propertyForRow(row) else { return [] }
        return FilterCondition.conditions(for: prop.type)
    }
}

// MARK: - Table View

extension FilterPanelViewController: UITableViewDataSource, UITableViewDelegate {

    enum Section: Int, CaseIterable {
        case dateRange
        case filters
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .dateRange:
            var count = 2
            if isFromDatePickerExpanded { count += 1 }
            if isToDatePickerExpanded { count += 1 }
            return count
        case .filters:
            return viewModel.filterRows.count + 1
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .dateRange: return "Date Range"
        case .filters:
            if viewModel.filterRows.isEmpty { return nil }
            return "Column Filters (\(viewModel.filterRows.count))"
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.contentView.backgroundColor = AppTheme.Colors.background
        header.textLabel?.font = AppTheme.Fonts.captionBold
        header.textLabel?.textColor = AppTheme.Colors.textMuted
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .filters where viewModel.filterRows.isEmpty: return 0
        default: return 36
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 4
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .dateRange:
            return dateRangeCell(at: indexPath)
        case .filters:
            if indexPath.row < viewModel.filterRows.count {
                return filterRowCell(at: indexPath)
            } else {
                return addFilterCell(at: indexPath)
            }
        case .none: return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .dateRange:
            if isDatePickerRow(indexPath) { return 350 }
            return 44
        case .filters:
            if indexPath.row < viewModel.filterRows.count { return 120 }
            return 50
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .dateRange:
            handleDateRangeTap(at: indexPath)
        case .filters:
            if indexPath.row >= viewModel.filterRows.count {
                viewModel.addFilterRow()
                tableView.reloadSections(IndexSet(integer: Section.filters.rawValue), with: .automatic)
            }
        case .none: break
        }
    }

    // MARK: - Date Range

    private func isDatePickerRow(_ indexPath: IndexPath) -> Bool {
        guard Section(rawValue: indexPath.section) == .dateRange else { return false }
        if isFromDatePickerExpanded, indexPath.row == 1 { return true }
        if isToDatePickerExpanded, indexPath.row == (isFromDatePickerExpanded ? 3 : 2) { return true }
        return false
    }

    private func handleDateRangeTap(at indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .dateRange else { return }
        var row = indexPath.row
        if isFromDatePickerExpanded && indexPath.row > 0 { row -= 1 }
        if isToDatePickerExpanded && indexPath.row > (isFromDatePickerExpanded ? 2 : 1) { row -= 1 }

        if row == 0 {
            isFromDatePickerExpanded.toggle()
            if isFromDatePickerExpanded { isToDatePickerExpanded = false }
        } else if row == 1 {
            isToDatePickerExpanded.toggle()
            if isToDatePickerExpanded { isFromDatePickerExpanded = false }
        }
        tableView.reloadSections(IndexSet(integer: Section.dateRange.rawValue), with: .automatic)
    }

    private func dateRangeCell(at indexPath: IndexPath) -> UITableViewCell {
        if isDatePickerRow(indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerCell", for: indexPath) as! DatePickerCell
            let isFrom: Bool
            if isFromDatePickerExpanded, indexPath.row == 1 { isFrom = true }
            else { isFrom = false }
            cell.configure(isFrom: isFrom, date: isFrom ? viewModel.dateRange.fromDate : viewModel.dateRange.toDate,
                onChange: { [weak self] date in
                    guard let self = self else { return }
                    if isFrom { self.viewModel.dateRange.fromDate = date }
                    else { self.viewModel.dateRange.toDate = date }
                },
                onDismiss: { [weak self] in
                    guard let self = self else { return }
                    self.isFromDatePickerExpanded = false
                    self.isToDatePickerExpanded = false
                    self.tableView.reloadSections(IndexSet(integer: Section.dateRange.rawValue), with: .automatic)
                }
            )
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "DateRangeCell", for: indexPath) as! DateRangeCell
        var row = indexPath.row
        if isFromDatePickerExpanded && indexPath.row > 0 { row -= 1 }
        if isToDatePickerExpanded && indexPath.row > (isFromDatePickerExpanded ? 2 : 1) { row -= 1 }

        if row == 0 {
            cell.configure(label: "From", date: viewModel.dateRange.fromDate, onClear: { [weak self] in
                guard let self = self else { return }
                self.viewModel.dateRange.fromDate = nil
                self.isFromDatePickerExpanded = false
                self.tableView.reloadSections(IndexSet(integer: Section.dateRange.rawValue), with: .automatic)
            })
        } else if row == 1 {
            cell.configure(label: "To", date: viewModel.dateRange.toDate, onClear: { [weak self] in
                guard let self = self else { return }
                self.viewModel.dateRange.toDate = nil
                self.isToDatePickerExpanded = false
                self.tableView.reloadSections(IndexSet(integer: Section.dateRange.rawValue), with: .automatic)
            })
        }
        return cell
    }

    private func filterRowCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterCell", for: indexPath) as! FilterCell
        let row = viewModel.filterRows[indexPath.row]
        let allPropertyNames = viewModel.allProperties.map { $0.name }

        let relationOpts = row.selectedProperty.map { viewModel.relationOptions(for: $0.name) } ?? []
        let relationLoadAttempted = row.selectedProperty.map { viewModel.relationFetchAttempted.contains($0.name) } ?? false

        cell.configure(
            row: row,
            allProperties: allPropertyNames,
            selectOptions: viewModel.selectOptions[row.selectedProperty?.name ?? ""] ?? [],
            relationOptions: relationOpts,
            conditions: conditionsForRow(indexPath.row),
            relationLoadAttempted: relationLoadAttempted
        )
        cell.onPropertyChange = { [weak self] name in
            guard let self = self, let prop = self.viewModel.allProperties.first(where: { $0.name == name }) else { return }
            self.viewModel.filterRows[indexPath.row].selectedProperty = prop
            self.viewModel.filterRows[indexPath.row].selectedCondition = nil
            self.viewModel.filterRows[indexPath.row].relationValue = nil
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
            // Trigger lazy loading for relation properties
            if prop.type == .relation {
                self.viewModel.loadRelationOptionsIfNeeded(for: name)
            }
        }
        cell.onConditionChange = { [weak self] condition in
            self?.viewModel.filterRows[indexPath.row].selectedCondition = condition
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        cell.onTextChange = { [weak self] text in
            self?.viewModel.filterRows[indexPath.row].textValue = text
        }
        cell.onNumberChange = { [weak self] num in
            self?.viewModel.filterRows[indexPath.row].numberValue = num
        }
        cell.onDateChange = { [weak self] date in
            self?.viewModel.filterRows[indexPath.row].dateValue = date
        }
        cell.onSelectChange = { [weak self] option in
            self?.viewModel.filterRows[indexPath.row].selectValue = option
        }
        cell.onRelationChange = { [weak self] id, title in
            self?.viewModel.filterRows[indexPath.row].relationValue = (id, title)
        }
        cell.onMultiSelectChange = { [weak self] option in
            self?.viewModel.filterRows[indexPath.row].multiSelectValue = option
        }
        cell.onRemove = { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: nil, message: "Remove this filter?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
                self.viewModel.removeFilterRow(at: indexPath.row)
                self.tableView.reloadSections(IndexSet(integer: Section.filters.rawValue), with: .automatic)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.sourceView = cell.removeButton
                popover.sourceRect = cell.removeButton.bounds
            }
            self.present(alert, animated: true)
        }
        return cell
    }

    private func addFilterCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AddFilterCell", for: indexPath) as! AddFilterCell
        return cell
    }
}

// MARK: - Custom Cells

class DateRangeCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let clearButton = UIButton(type: .system)
    private var clearButtonWidth: NSLayoutConstraint?
    private var onClear: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = AppTheme.Colors.cardBackground
        layer.cornerRadius = AppTheme.CornerRadius.medium
        clipsToBounds = true
        selectionStyle = .none

        titleLabel.font = AppTheme.Fonts.body
        titleLabel.textColor = AppTheme.Colors.textPrimary
        valueLabel.font = AppTheme.Fonts.bodyMedium
        valueLabel.textColor = AppTheme.Colors.textSecondary
        valueLabel.textAlignment = .right
        chevron.tintColor = AppTheme.Colors.textMuted
        chevron.contentMode = .scaleAspectFit

        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = AppTheme.Colors.textMuted
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(chevron)
        contentView.addSubview(clearButton)

        [titleLabel, valueLabel, chevron].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let cbWidth = clearButton.widthAnchor.constraint(equalToConstant: 24)
        clearButtonWidth = cbWidth

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),

            clearButton.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -4),
            clearButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cbWidth,
            clearButton.heightAnchor.constraint(equalToConstant: 24),

            valueLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8)
        ])
    }

    func configure(label: String, date: Date?, onClear: (() -> Void)? = nil) {
        titleLabel.text = label
        self.onClear = onClear
        let hasDate = date != nil
        clearButton.isHidden = !hasDate
        clearButtonWidth?.constant = hasDate ? 24 : 0
        if let date = date {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            valueLabel.text = fmt.string(from: date)
            valueLabel.textColor = AppTheme.Colors.textPrimary
        } else {
            valueLabel.text = "Not set"
            valueLabel.textColor = AppTheme.Colors.textMuted
        }
    }

    @objc private func clearTapped() {
        onClear?()
    }
}

class DatePickerCell: UITableViewCell {
    private let picker = UIDatePicker()
    private var isFrom = true
    private var onChange: ((Date) -> Void)?
    private var onDismiss: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = AppTheme.Colors.cardBackgroundAlt
        selectionStyle = .none
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.tintColor = AppTheme.Colors.primaryBrown
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        picker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: contentView.topAnchor),
            picker.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    func configure(isFrom: Bool, date: Date?, onChange: @escaping (Date) -> Void, onDismiss: (() -> Void)? = nil) {
        self.isFrom = isFrom
        self.onChange = onChange
        self.onDismiss = onDismiss
        if let d = date { picker.date = d }
    }

    @objc private func dateChanged() {
        onChange?(picker.date)
        onDismiss?()
    }
}

class FilterCell: UITableViewCell {
    private let columnButton = UIButton(type: .system)
    private let conditionButton = UIButton(type: .system)
    let removeButton = UIButton(type: .system)
    private let valueContainer = UIView()
    private var valueTextField: UITextField?
    private var valuePickerButton: UIButton?
    private var datePicker: UIDatePicker?
    private var valueLabel: UILabel?

    var onPropertyChange: ((String) -> Void)?
    var onConditionChange: ((FilterCondition) -> Void)?
    var onTextChange: ((String) -> Void)?
    var onNumberChange: ((Double) -> Void)?
    var onDateChange: ((Date) -> Void)?
    var onSelectChange: ((String) -> Void)?
    var onRelationChange: ((String, String) -> Void)?
    var onMultiSelectChange: ((String) -> Void)?
    var onRemove: (() -> Void)?

    private var currentType: NotionPropertyType?
    private var currentCondition: FilterCondition?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = AppTheme.Colors.cardBackground
        layer.cornerRadius = AppTheme.CornerRadius.medium
        clipsToBounds = true
        selectionStyle = .none

        columnButton.titleLabel?.font = AppTheme.Fonts.captionMedium
        columnButton.tintColor = AppTheme.Colors.primaryBrown
        columnButton.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        columnButton.layer.cornerRadius = AppTheme.CornerRadius.small
        columnButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        columnButton.translatesAutoresizingMaskIntoConstraints = false

        conditionButton.titleLabel?.font = AppTheme.Fonts.captionMedium
        conditionButton.tintColor = AppTheme.Colors.primaryBrown
        conditionButton.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        conditionButton.layer.cornerRadius = AppTheme.CornerRadius.small
        conditionButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        conditionButton.translatesAutoresizingMaskIntoConstraints = false

        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = AppTheme.Colors.textMuted
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        valueContainer.translatesAutoresizingMaskIntoConstraints = false
        valueContainer.backgroundColor = AppTheme.Colors.cardBackgroundAlt
        valueContainer.layer.cornerRadius = AppTheme.CornerRadius.small

        contentView.addSubview(columnButton)
        contentView.addSubview(conditionButton)
        contentView.addSubview(removeButton)
        contentView.addSubview(valueContainer)

        NSLayoutConstraint.activate([
            columnButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            columnButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            columnButton.heightAnchor.constraint(equalToConstant: 32),

            conditionButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            conditionButton.leadingAnchor.constraint(equalTo: columnButton.trailingAnchor, constant: 6),
            conditionButton.heightAnchor.constraint(equalToConstant: 32),

            removeButton.centerYAnchor.constraint(equalTo: columnButton.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            removeButton.widthAnchor.constraint(equalToConstant: 28),
            removeButton.heightAnchor.constraint(equalToConstant: 28),

            valueContainer.topAnchor.constraint(equalTo: columnButton.bottomAnchor, constant: 8),
            valueContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            valueContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            valueContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            valueContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])

        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    func configure(
        row: FilterPanelViewModel.FilterRow,
        allProperties: [String],
        selectOptions: [String],
        relationOptions: [(id: String, title: String)],
        conditions: [FilterCondition],
        relationLoadAttempted: Bool = false
    ) {
        let propName = row.selectedProperty?.name ?? "Column"
        columnButton.setTitle(propName, for: .normal)
        columnButton.showsMenuAsPrimaryAction = true
        columnButton.menu = UIMenu(title: "Column", children: allProperties.map { name in
            UIAction(title: name, state: name == propName ? .on : .off) { [weak self] _ in
                self?.onPropertyChange?(name)
            }
        })

        if let condition = row.selectedCondition {
            conditionButton.setTitle(condition.displayName, for: .normal)
        } else {
            conditionButton.setTitle("Condition", for: .normal)
        }
        conditionButton.showsMenuAsPrimaryAction = true
        conditionButton.menu = UIMenu(title: "Condition", children: conditions.map { cond in
            UIAction(title: cond.displayName, state: cond == row.selectedCondition ? .on : .off) { [weak self] _ in
                self?.onConditionChange?(cond)
            }
        })

        currentType = row.selectedProperty?.type
        currentCondition = row.selectedCondition
        rebuildValueInput(type: row.selectedProperty?.type, condition: row.selectedCondition, row: row, selectOptions: selectOptions, relationOptions: relationOptions, relationLoadAttempted: relationLoadAttempted)
    }

    private func rebuildValueInput(type: NotionPropertyType?, condition: FilterCondition?, row: FilterPanelViewModel.FilterRow, selectOptions: [String], relationOptions: [(id: String, title: String)], relationLoadAttempted: Bool = false) {
        valueContainer.subviews.forEach { $0.removeFromSuperview() }
        valueTextField = nil
        valuePickerButton = nil
        datePicker = nil
        valueLabel = nil

        guard let type = type, let condition = condition else {
            let lbl = UILabel()
            lbl.text = "Select a column and condition"
            lbl.font = AppTheme.Fonts.caption
            lbl.textColor = AppTheme.Colors.textMuted
            lbl.translatesAutoresizingMaskIntoConstraints = false
            valueContainer.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                lbl.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12)
            ])
            return
        }

        if condition == .isEmpty || condition == .isNotEmpty || condition == .isChecked || condition == .isUnchecked {
            let lbl = UILabel()
            lbl.text = condition == .isChecked ? "Will match checked items" :
                       condition == .isUnchecked ? "Will match unchecked items" :
                       condition == .isEmpty ? "Will match empty values" : "Will match non-empty values"
            lbl.font = AppTheme.Fonts.caption
            lbl.textColor = AppTheme.Colors.textSecondary
            lbl.translatesAutoresizingMaskIntoConstraints = false
            valueContainer.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                lbl.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12)
            ])
            return
        }

        switch type {
        case .title, .richText, .url, .email, .phoneNumber:
            let tf = UITextField()
            tf.placeholder = "Enter value"
            tf.font = AppTheme.Fonts.body
            tf.textColor = AppTheme.Colors.textPrimary
            tf.text = row.textValue
            tf.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
            tf.translatesAutoresizingMaskIntoConstraints = false
            valueContainer.addSubview(tf)
            NSLayoutConstraint.activate(tfConstraints(for: tf))
            self.valueTextField = tf
            addDoneToolbar(to: tf)

        case .number:
            let tf = UITextField()
            tf.placeholder = "Enter number"
            tf.font = AppTheme.Fonts.body
            tf.textColor = AppTheme.Colors.textPrimary
            tf.keyboardType = .decimalPad
            if let v = row.numberValue { tf.text = String(format: "%.2f", v) }
            tf.addTarget(self, action: #selector(numberFieldChanged), for: .editingChanged)
            tf.translatesAutoresizingMaskIntoConstraints = false
            valueContainer.addSubview(tf)
            NSLayoutConstraint.activate(tfConstraints(for: tf))
            self.valueTextField = tf
            addDoneToolbar(to: tf)

        case .date:
            let dp = UIDatePicker()
            dp.datePickerMode = .date
            dp.preferredDatePickerStyle = .compact
            dp.tintColor = AppTheme.Colors.primaryBrown
            if let d = row.dateValue { dp.date = d }
            dp.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
            dp.translatesAutoresizingMaskIntoConstraints = false
            valueContainer.addSubview(dp)
            NSLayoutConstraint.activate([
                dp.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                dp.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 8)
            ])
            self.datePicker = dp

        case .select, .status:
            if selectOptions.isEmpty {
                let tf = UITextField()
                tf.placeholder = "Type option name"
                tf.font = AppTheme.Fonts.body
                tf.textColor = AppTheme.Colors.textPrimary
                tf.text = row.selectValue
                tf.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
                tf.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(tf)
                NSLayoutConstraint.activate(tfConstraints(for: tf))
                self.valueTextField = tf
                addDoneToolbar(to: tf)
            } else {
                let btn = UIButton(type: .system)
                btn.setTitle(row.selectValue ?? "Select option", for: .normal)
                btn.titleLabel?.font = AppTheme.Fonts.body
                btn.tintColor = AppTheme.Colors.primaryBrown
                btn.contentHorizontalAlignment = .left
                btn.showsMenuAsPrimaryAction = true
                btn.menu = UIMenu(title: "Options", children: selectOptions.map { opt in
                    UIAction(title: opt, state: opt == row.selectValue ? .on : .off) { [weak self] _ in
                        self?.onSelectChange?(opt)
                        self?.valuePickerButton?.setTitle(opt, for: .normal)
                    }
                })
                btn.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(btn)
                NSLayoutConstraint.activate([
                    btn.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                    btn.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
                    btn.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -8)
                ])
                self.valuePickerButton = btn
            }

        case .multiSelect:
            if selectOptions.isEmpty {
                let tf = UITextField()
                tf.placeholder = "Type option name"
                tf.font = AppTheme.Fonts.body
                tf.textColor = AppTheme.Colors.textPrimary
                tf.text = row.multiSelectValue
                tf.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
                tf.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(tf)
                NSLayoutConstraint.activate(tfConstraints(for: tf))
                self.valueTextField = tf
                addDoneToolbar(to: tf)
            } else {
                let btn = UIButton(type: .system)
                btn.setTitle(row.multiSelectValue ?? "Select option", for: .normal)
                btn.titleLabel?.font = AppTheme.Fonts.body
                btn.tintColor = AppTheme.Colors.primaryBrown
                btn.contentHorizontalAlignment = .left
                btn.showsMenuAsPrimaryAction = true
                btn.menu = UIMenu(title: "Options", children: selectOptions.map { opt in
                    UIAction(title: opt, state: opt == row.multiSelectValue ? .on : .off) { [weak self] _ in
                        self?.onMultiSelectChange?(opt)
                        self?.valuePickerButton?.setTitle(opt, for: .normal)
                    }
                })
                btn.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(btn)
                NSLayoutConstraint.activate([
                    btn.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                    btn.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
                    btn.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -8)
                ])
                self.valuePickerButton = btn
            }

        case .relation:
            if relationOptions.isEmpty {
                // Show loading or empty state
                let lbl = UILabel()
                lbl.text = relationLoadAttempted ? "No relation options available" : "Loading relation options…"
                lbl.font = AppTheme.Fonts.caption
                lbl.textColor = AppTheme.Colors.textSecondary
                lbl.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(lbl)
                NSLayoutConstraint.activate([
                    lbl.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                    lbl.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12)
                ])
            } else {
                let btn = UIButton(type: .system)
                let currentTitle = row.relationValue?.title ?? "Select relation"
                btn.setTitle(currentTitle, for: .normal)
                btn.titleLabel?.font = AppTheme.Fonts.body
                btn.tintColor = AppTheme.Colors.primaryBrown
                btn.contentHorizontalAlignment = .left
                btn.showsMenuAsPrimaryAction = true
                btn.menu = UIMenu(title: "Related pages", children: relationOptions.map { rel in
                    UIAction(title: rel.title, state: rel.id == row.relationValue?.id ? .on : .off) { [weak self] _ in
                        self?.onRelationChange?(rel.id, rel.title)
                        self?.valuePickerButton?.setTitle(rel.title, for: .normal)
                    }
                })
                btn.translatesAutoresizingMaskIntoConstraints = false
                valueContainer.addSubview(btn)
                NSLayoutConstraint.activate([
                    btn.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
                    btn.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
                    btn.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -8)
                ])
                self.valuePickerButton = btn
            }

        case .checkbox:
            break
        }
    }

    private func tfConstraints(for tf: UITextField) -> [NSLayoutConstraint] {
        return [
            tf.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
            tf.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
            tf.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -8)
        ]
    }

    private func addDoneToolbar(to textField: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .plain, target: textField, action: #selector(UIResponder.resignFirstResponder))
        done.tintColor = AppTheme.Colors.primaryBrown
        toolbar.items = [flex, done]
        textField.inputAccessoryView = toolbar
    }

    @objc private func textFieldChanged() {
        onTextChange?(valueTextField?.text ?? "")
    }

    @objc private func numberFieldChanged() {
        let text = valueTextField?.text ?? ""
        let cleaned = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        onNumberChange?(Double(cleaned) ?? 0)
    }

    @objc private func datePickerChanged() {
        if let dp = datePicker {
            onDateChange?(dp.date)
        }
    }
}

class AddFilterCell: UITableViewCell {
    private let addButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .default

        addButton.setTitle("+ Add Filter", for: .normal)
        addButton.titleLabel?.font = AppTheme.Fonts.bodyMedium
        addButton.tintColor = AppTheme.Colors.primaryBrown
        addButton.isUserInteractionEnabled = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            addButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
}
