# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no CocoaPods/SPM, no CI. Deployment target 26.0. Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry & Navigation Flow

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes to: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

**Dashboard → Analytics** (button, selected-month data, no API calls). **ExpenseList / IncomeList** → tap row opens `TransactionDetailViewController` (view/edit/delete). Both lists present `FilterPanelViewController` modally.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`.

## Month Classification Gotcha

`tableView.reloadData()` is not synchronous — `didAutoSelectMonthClassification` fires before cells exist. **Do not** move auto-select to `viewDidLoad`. Fix in `cellForRowAt`: after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match.

## Edit & Delete

Triggered from `TransactionDetailViewController` (tapped from list).
- **Edit**: `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)` populates `fieldValues` from `rawProperties`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH returns updated `NotionPage`), then `onEditComplete` → `replaceExpense`/`replaceIncome` on cache.
- **Delete**: confirmation alert → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then cache remove helpers.

### Fixed bugs to avoid reintroducing
- **Date-shift**: `applyEditPrefill()` using `ISO8601DateFormatter` for date-only strings parses `"2024-01-15"` as midnight UTC → previous day in local tz. Use `DateComponents` with `hour=12` local (`TransactionNormalizer.extractDate()`).
- **Number parsing**: `collectFieldValues()` replacing `","` with `"."` on formatted numbers (`"1,600"` → `"1.600"` → `1.6`). Strip commas: `replacingOccurrences(of: ",", with: "")`.
- **Stale rawProperties**: `updateTransaction` must return `NotionPage` for PATCH response so re-edit shows fresh values. Parse response in `buildUpdatedTransaction(from:updatedPage:)`.
- **Cache gap**: new transactions saved to Notion must be added to `SessionCacheManager` (stored via `lastCreatedPage` → `NormalizedTransaction` in `showSuccess()` → `addExpense`/`addIncome`).
- Cache helpers (NSLock-protected): `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`, `addExpense`, `addIncome`.
- **Edit mode keyboard flicker**: In edit mode, `computeSuggestions()` found the existing transaction in the cache (it matches itself). Guard `!categoryFieldIsEmpty && !viewModel.isEditMode` passed because `!isEditMode` short-circuits to `false`. Suggestion row insertion triggered `tableView.reloadData()`, destroying the title cell and dismissing the keyboard. Fix: embed suggestion chips directly in `FormFieldCell` (title cell) instead of a separate table row. No table update methods are called for suggestion updates — only `cell.updateSuggestions()` which modifies subviews in-place. Re-enabled edit mode suggestions with `hasUserEditedTitleForSuggestions` flag.
- **iOS 26 performBatchUpdates crash**: `tableView.reloadRows()` internally wraps in `performBatchUpdates` on iOS 26, which conflicts with `UIDatePicker.compact`'s internal variant selector tracking, causing "1 inserted, 1 deleted" assertion failure. Fix: suggestions are embedded inside the title `FormFieldCell`. `performBatchUpdates(nil)` is called after cell update for height recalculation only — no row count changes, so no batch validation conflict.
- **Suggestions at bottom**: `computeSuggestions()` never set `showSuggestions = true` — the old `refreshSuggestionRow()` always computed `shouldShow = false`. Set `showSuggestions = true` before calling the refresh method.
- **Placeholder disappears**: When suggestions appear, the `contentStack` grew taller than the cell's fixed height, compressing the text field below 30pt and hiding the placeholder. `performBatchUpdates(nil)` recalculates the cell height so the text field stays full height.
- **Single match suppressed**: `suggestions()` required `totalMatched >= 2` unconditionally. Now uses two-rule gate: `totalMatched >= 2 && confidence >= 0.5` (existing) OR `totalMatched == 1 && confidence >= 0.5 && matchStrength >= .strong`.

## Expense Category Suggestions

Add Transaction shows up to 3 suggestion chips ("Use Category?") inline below the title field when typing an expense title. No Notion calls, no AI, no auto-apply without tap.

### Files
- `Notra/Helpers/ExpenseCategorySuggestionEngine.swift` — model + merchant→category map engine
- `Notra/Helpers/SuggestionChipView.swift` — tappable pill chip view
- `Notra/Controllers/AddTransactionViewController.swift` — integration (title observation, suggestion chips embedded in FormFieldCell, apply)

### Engine behavior
Reads `SessionCacheManager.shared.allExpenses` on first `computeSuggestions()`. For each cached expense, normalizes the title (lowercase, strip punctuation/numbers, remove noise words: store/order/purchase/transaction/inc/llc/com/ltd/corp) and extracts the category from `rawProperties[categoryPropertyName]` (select name, relation page ID+title, multi-select name, status name), falling back to `NormalizedTransaction.category`.

**Matching**: exact → contains → first-token (pooled).  
**Min matching past expenses**: 2. **Min confidence**: 0.50. **Max chips**: 3.  
**Sort**: count desc → confidence desc → name alpha.  
**After save**: `noteSavedExpense()` updates the in-memory map via `buildSuggestionEntryForSavedExpense()`.

### Suggestion container in title cell
Suggestions chips are embedded directly inside the title `FormFieldCell` (not a separate table row). `FormFieldCell` has a `suggestionContainer` (UILabel + horizontal chip stack) created once in `setup()`. The container is hidden/shown by toggling `isHidden`. Only chip arranged subviews are swapped on update — zero table view insert/delete/reload/reloadRows methods are ever called for the suggestion lifecycle. `updateSuggestions(_:onTap:)` modifies subviews in-place. `performBatchUpdates(nil)` is called after cell update to recalculate the cell height so the text field isn't compressed (which would hide the placeholder). No row count changes, so no batch validation crash.

### Suggestion UI layout
The suggestion row is a horizontal `UIStackView` inside the title cell's `contentStack`:
```
contentStack (vertical, spacing 0):
  textField
  suggestionRowStack (horizontal, spacing 6, isHidden when empty):
    suggestionLabel ("Suggestions", 12pt regular, textMuted)
    suggestionChipStack (horizontal, spacing 6)
    spacer
```
When hidden, the vertical stack collapses the suggestion row to 0 height — no blank gap.
When visible, the row adds ~28pt to the cell height.
Chips: 28pt height, `accent.withAlphaComponent(0.12)` background, `border.withAlphaComponent(0.3)` border, `accent` text, 12pt medium font, 10pt horizontal padding.

### States
- **Debounce**: 400ms on `editingChanged` + immediate on `editingDidEnd`. Min 3 normalized chars.
- **Hide when**: Income tab, no title, no category field, unsupported category type, category already set, edit mode without title edit, no matching suggestions.
- **Manual category** (picker or chip tap): hides suggestions.
- **Edit mode**: no suggestions until user edits the title (`hasUserEditedTitleForSuggestions`).
- **Form reset**: clears all suggestion state.

### Category value application
| Field type | ViewModel method | Payload |
|---|---|---|
| `.select` / `.status` | `updateSelectValue(propertyName:value:)` | `{"select"/"status": {"name": "..."}}` |
| `.relation` | `updateRelationValue(propertyName:ids:)` | `{"relation": [{"id": "..."}]}` |
| `.multiSelect` | `updateMultiSelectValue(propertyName:values:)` | `{"multi_select": [{"name": "..."}]}` |

For relation suggestions, the page ID is extracted from the past expense's `rawProperties["categoryFieldName"]?.relation?.first?.id`, and the display title from `expense.category`.

## Dashboard

All sections use **selected-month data only** — no API calls for display. Card views defined inline in `DashboardViewController.swift`.

Section hierarchy: Hero → Overview (Spent/Income/Balance) → Monthly Status → Monthly Budget (tappable category cards push ExpenseList filtered by category+month) → Recent Activity → Quick Checks → Explore (Expenses/Income/Analytics cards). `sectionSpacing: CGFloat = 28`. FAB clearance: `scrollView.contentInset.bottom = 96`.

- **Overview cards**: Total Spent/Income push filtered lists (chevron visible); Net Balance not tappable.
- **Refresh**: `viewWillAppear` calls `viewModel.reloadFromCache()` (reads `SessionCacheManager.shared.allExpenses/allIncomes`, recomputes). No API calls. Skips if cache empty (first load by `loadData()`).
- **Sub-1% fix**: `privateFormatPercent` → use `<1%` pattern (was `maximumFractionDigits=0` rounding <0.5% to `0%`).
- **Budget 100% fix**: `GroupedTransactionSection.swift:87`: `if pct > 1.0` for overBudget (was `>= 1.0` marking exactly-at-budget as overBudget).
- Budget auto-detects number properties: "monthly budget"=100 → "budget"=90 → "limit"=80 → keyword=40, fallback to formula/rollup. Groups expenses by category relation ID.
- **FAB**: presents `AddTransactionViewController` full-screen (`modalPresentationStyle = .fullScreen` — no swipe-to-dismiss).
- **Deep-link**: while dashboard is presented, `SceneDelegate.navigateToAddTransaction` dismisses any presented VC first (`nav.dismiss(animated: false)`) before presenting add screen.

## Filter System

`FilterPanelViewController` (modal) → `FilterPanelViewModel` → `FilterEngine` (AND-logic on `rawProperties`). Relation properties load lazily from target DB. Post-filter search via `LocalSearchService.transactionMatchesSearch(_:query:)` (after FilterEngine, before grouping).

**Date "Between" removed**: `.between` condition excluded from date properties (`TransactionFilter.swift:41`). Date properties show only `Before`, `After`, `Is Empty`, `Is Not Empty`. From/to filtering is handled by separate Date Range section (section 0) with two `.inline` date pickers.

**Initial filter passing**: Both `ExpenseListViewController`/`IncomeListViewController` accept `init(initialFilters:initialDateRange:)`. Apply in `viewDidLoad` after `loadFromCache()`:
```swift
if initialFilters != nil || initialDateRange != nil {
    viewModel.applyFilters(filters: initialFilters ?? [], dateRange: initialDateRange)
}
```

`FilterChipView` (28pt pill, `"PropertyName: value"`). Tapping × calls `viewModel.removeFilter(byId:)`/`viewModel.clearDateRange()`.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle` = `(AppTheme.currentMode == .dark ? .dark : .light)`. Toggle at `AppConstants.swift:105`: `static var currentMode: ThemeMode = .dark`. Warm cream/brown palette via `AppTheme.Colors`.

**Never hardcode `UIColor.white` for segment text** — use `AppTheme.Colors.buttonContent` (adapts to current theme).

### Swipe action colors
- **Edit**: `AppTheme.Colors.secondaryBrown` (amber/tan)
- **Delete**: `AppTheme.Colors.expense.withAlphaComponent(0.8)` (coral-red)

## Persistence

- **UserDefaults** via `UserDefaultsManager` (shared): token, page ID/title.
- **`ColumnMappingService`** persists roles & column mappings under `databaseMappings`/`columnMappings` keys.

## Settings — Health

`SetupMetadataService.loadHealthData()` fires async schema fetches on `viewDidAppear` — caches schemas and relation target DB IDs into `SessionCacheManager`. Two sections: **Notion Connection** (12 rows, read-only) and **Setup Checklist** (12 required + 4 recommended). Checklist reads cached data exclusively; no API calls in computed properties.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Dead Code

- `SetupCompleteViewController.swift` — never instantiated
- `ViewController.swift` — Xcode boilerplate
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Table views: `.plain` except `AddTransaction` and `Settings` which use `.insetGrouped`
- All UI programmatic; no storyboard segues or xibs
- Use `AppTheme.Fonts`, `AppTheme.CornerRadius`, `AppTheme.Shadow`, `AppTheme.styleNavigationBar()` for UI consistency
- `FinanceCell` in `Controllers/` is the shared cell for expense/income lists
- `AGENTS.md` is gitignored (not version controlled)
