# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no package managers, no CI. Deployment target Debug=26.0, Release=26.4. Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry & Navigation

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`.

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`.

## Gotchas

Canonical list of patterns an agent would likely miss or reintroduce:

- **No `convertFromSnakeCase`**: Every `JSONDecoder()` uses default config. All `CodingKeys` must manually map snake_case keys (e.g. `"rich_text"` → `richText`). Missing this caused `NotionPropertyValue.richText` to always be `nil`.
- **Date-only strings shift tz**: Parsing "2024-01-15" with `ISO8601DateFormatter` yields midnight UTC → previous day in local tz. Use `DateComponents` with `hour=12` local (`TransactionNormalizer.extractDate()`).
- **Number parsing**: Strip commas via `replacingOccurrences(of: ",", with: "")` — do NOT replace commas with dots.
- **PATCH returns updated page**: `updateTransaction` must return `NotionPage` from PATCH response so re-edits show fresh values. Parse in `buildUpdatedTransaction(from:updatedPage:)`.
- **Cache on create**: New transactions must be manually added to `SessionCacheManager` (`addExpense`/`addIncome`) in `showSuccess()` via `lastCreatedPage`.
- **iOS 26 `performBatchUpdates` crash**: `tableView.reloadRows()` wraps in `performBatchUpdates` on iOS 26, conflicting with `UIDatePicker.compact`. Avoid row count changes in `performBatchUpdates` blocks. Use `performBatchUpdates(nil)` only for height recalculation.
- **Budget over-budget check**: `GroupedTransactionSection.swift:87` — use `pct > 1.0` (not `>= 1.0`) to trigger over-budget state.
- **Sub-1% formatting**: Use explicit `"<1%"` string. `maximumFractionDigits=0` rounds <0.5% to `"0%"`.
- **Mapping cell info icon recycling**: `MappingCell.configure()` must `infoButton.isHidden = true` at start. Otherwise recycled `.appMetadata` cells keep the icon visible on standard rows.
- **Split metadata column type**: Column picker filter for `.appMetadata` must accept both `"rich_text"` and `"text"` since Notion API may return either.
- **Suggestions embedded in title cell**: Suggestion chips live inside `FormFieldCell`, not a separate table row. No `tableView.reloadData()`/`reloadRows()` for suggestion lifecycle — only `cell.updateSuggestions()`.
- **`tableView.reloadData()` not synchronous**: Month classification auto-select must fire in `cellForRowAt` (check `viewModel.fieldValues[field.propertyName]`), not `viewDidLoad`.

## Edit & Delete

Triggered from `TransactionDetailViewController`. Edit: `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH returns updated `NotionPage`), then cache `replaceExpense`/`replaceIncome`. Delete: confirmation → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then cache remove helpers.

## Cache

`SessionCacheManager` with `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`, `addExpense`, `addIncome`. Regroups by date after every mutation. NSLock-protected.

## Expense Category Suggestions

Up to 3 suggestion chips inline in the title `FormFieldCell`. 400ms debounce + immediate on `editingDidEnd`. Min 3 normalized chars. Hidden when: income tab, no title, no category field, unsupported category type, category already set, edit mode without title edit.

## Split Details

Optional `expenseAppMetadataProperty` (Text column in Expense DB) stores JSON `SplitMetadata`. Notion API type is `rich_text`; filter both `"rich_text"` and `"text"`. Decodes old `expenseSplitDetailsProperty` key. Skipped from Add Transaction form. Split works unmapped with warning toast.

`SplitMetadata` holds `enabled`, `paidAmount`, `myShare`, `theyOwe`, `type`, `status`, `splitWith`, `inputs`. `SplitMethodType`: `splitEqually`, `exactAmounts`, `percent`, `shares`, `adjustment`. Legacy `"50/50"` → `splitEqually`, `"Custom Amount"` → `exactAmounts` via `fromLegacy()`.

- **UI**: 2x2 method chip grid in `SplitDetailCell`. Equal → summary tiles. Exact → dual side-by-side fields (recursion via `activeFieldTag` + `isUpdatingProgrammatically`). Percent → side-by-side + inline result. Adjust → toggle + amount + inline result. All in `bottomStack` (UIStackView, auto-collapses hidden subviews).
- **Detail screen**: Two-column stat tile grid in `TransactionDetailViewController`. Rows: Counted/Paid, Owed/Status. Bottom: Method, Split with.
- **List display**: Two-line `"Split · {Method}\nPaid $X.XX · Owed $X.XX"` in `FinanceCell.paidAmountLabel`. `paidAmountLabel` physically removed from `contentStack.arrangedSubviews` for non-split (no residual gap), re-added only for split.
- **Info sheet**: `SplitHelpViewController` presented as `.overFullScreen` with cross-dissolve.

## Dashboard

All sections use selected-month data only — no API calls. Section hierarchy: Hero → Overview → Monthly Status → Monthly Budget (tappable, push ExpenseList) → Recent Activity → Quick Checks → Explore. `sectionSpacing = 28`. FAB: full-screen. Budget auto-detects number properties in category DB by keyword scoring; groups expenses by category relation ID.

## Filter System

`FilterPanelViewController` (modal) → `FilterPanelViewModel` → `FilterEngine` (AND-logic on `rawProperties`). Post-filter search via `LocalSearchService`. `.between` excluded from date properties; date pickers handled by separate From/To inline date pickers.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle = (AppTheme.currentMode == .dark ? .dark : .light)`. Default mode: `.dark` (AppConstants.swift:105). Warm cream/brown palette. Never hardcode `UIColor.white` for segment text — use `AppTheme.Colors.buttonContent`.

## Persistence

- **UserDefaults** via `UserDefaultsManager`: token, page ID/title.
- **`ColumnMappingService`** persists roles & mappings under `databaseMappings`/`columnMappings` keys (JSON).
- **ColumnMapping**: custom `CodingKeys` — decodes old `expenseSplitDetailsProperty` into `expenseAppMetadataProperty`; encodes only the new key.

## Architecture Notes

- **AnalyticsViewController**: ~3000 lines — all chart views inline. USD hardcoded. Top 6 + "Other" in donut. Zero API calls.
- **NotionService**: Two API versions — standard uses `2022-06-28` (`AppConstants.API.notionVersion`), data source APIs hardcode `2025-09-03`.
- **NotionDataFetcher**: Three-tier fallback: (1) data source API → (2) search → (3) direct DB query. Pagination (`page_size=100`).
- **CategoryParserService**: First 100 rows only (no pagination).
- **TransactionNormalizer**: Amounts are `abs()`'d. Deduplicates by page id. Relation category resolution uses `relationLookupMap`.
- **DatabaseDiscoveryService**: Searches ALL accessible databases via `POST /search`. Manually adds `"title"` property if missing.
- **NotionService.fetchTopLevelPages**: Only workspace-level pages (`parent.type == "workspace"`).
- **DynamicFormValue.isEmpty**: For `.checkbox`, always `false`.
- **Table views**: `.plain` except `AddTransaction`, `Settings`, and `FilterPanel` which use `.insetGrouped`.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Dead Code

- `SetupCompleteViewController.swift`, `ViewController.swift` — never instantiated
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Use `AppTheme.Fonts`, `AppTheme.CornerRadius`, `AppTheme.Shadow`, `AppTheme.styleNavigationBar()` for consistency
- `AGENTS.md` is gitignored (not version controlled)
