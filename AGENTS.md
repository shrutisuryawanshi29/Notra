# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no CocoaPods/SPM, no CI. Deployment target 26.4 (Release) / 26.0 (Debug). Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry Flow

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes to:
`TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`. Fix when ready.

## Month Classification Gotcha

`tableView.reloadData()` is not synchronous — `didAutoSelectMonthClassification` can fire before cells exist. **Do not** move auto-select to `viewDidLoad`. Fix in `cellForRowAt` (~line 536): after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match.

## Edit & Delete

- **Edit**: `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)` → populates `fieldValues` from `rawProperties`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then `onEditComplete` → `replaceExpense`/`replaceIncome` on cache.
- **Delete**: confirmation alert → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then `removeExpense(byPageId:)`/`removeIncome(byPageId:)`.

Cache helpers (NSLock-protected) in `SessionCacheManager`: `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`.

## Dashboard

All sections use **selected-month data only** — no API calls. Card views defined inline in `DashboardViewController.swift`.

Budget auto-detects number properties by scoring: "monthly budget"=100 → "budget"=90 → "limit"=80 → keyword=40, fallback to formula/rollup. Groups expenses by category relation ID.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle` = `(AppTheme.currentMode == .dark ? .dark : .light)`. Toggle at `AppConstants.swift:105`:
```swift
static var currentMode: ThemeMode = .dark
```
Warm cream/brown palette, all programmatic via `AppTheme.Colors`.

## Local Search

`LocalSearchService.transactionMatchesSearch(_:query:)` — case-insensitive on title, category, amount, date, richText, select/status, multi_select, relation titles, url, email, phone, number. Applied **post-filters**: `allTransactions → FilterEngine → applySearch → group → sections`. Does not mutate cache or call API.

## Filter Chips

`FilterChipView` (28pt pill, `chipDisplayText` format like `"PropertyName: value"`). Date range renders as `"Date: May 1 – May 31"`. Tapping × calls `viewModel.removeFilter(byId:)` or `viewModel.clearDateRange()`.

## Persistence

- **UserDefaults** via `UserDefaultsManager` (shared): token, page ID/title — accessed as computed properties mapped to `AppConstants.UserDefaultsKeys`.
- **`ColumnMappingService`** persists roles & column mappings to `UserDefaults` under `databaseMappings`/`columnMappings` keys.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefix convention: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Key Files

| File | Role |
|---|---|
| `Services/NotionService.swift` | API client (`api.notion.com/v1`, `2022-06-28`) |
| `Services/NotionDataFetcher.swift` | DB row fetching with fallback chain |
| `Services/SessionCacheManager.swift` | Thread-safe cache (NSLock) |
| `Services/TransactionInsertService.swift` | POST `/pages`, PATCH for updates |
| `Services/TransactionNormalizer.swift` | Notion API pages → `NormalizedTransaction` |
| `Services/FilterEngine.swift` | Client-side AND-logic on `rawProperties` |
| `Services/SetupStateManager.swift` | Startup routing, state check, reset |
| `Helpers/AppConstants.swift` | API config, AppTheme (palette, fonts, spacing, shadows) |

## Dead Code

- `SetupCompleteViewController.swift` — never instantiated
- `ViewController.swift` at project root — Xcode boilerplate
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Table views: `.plain` except `AddTransaction` which uses `.insetGrouped`
- All UI programmatic; no storyboard segues or xibs
- `AGENTS.md` is gitignored (not version controlled)
