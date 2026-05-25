# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no CocoaPods/SPM, no CI. Deployment target 26.4 (Release) / 26.0 (Debug). Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry & Navigation Flow

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes to: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

**Dashboard → Analytics** (via button, selected-month data, no API calls). **ExpenseList / IncomeList** → tap row opens `TransactionDetailViewController` (view/edit/delete). Both lists present `FilterPanelViewController` modally for column-based filtering.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`. Fix when ready.

## Month Classification Gotcha

`tableView.reloadData()` is not synchronous — `didAutoSelectMonthClassification` can fire before cells exist. **Do not** move auto-select to `viewDidLoad`. Fix in `cellForRowAt` (~line 536): after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match.

## Edit & Delete

- **Edit**: `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)` → populates `fieldValues` from `rawProperties`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then `onEditComplete` → `replaceExpense`/`replaceIncome` on cache.
- **Delete**: confirmation alert → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then `removeExpense(byPageId:)`/`removeIncome(byPageId:)` on cache.
- Both triggered from `TransactionDetailViewController` (tapped from list).

Cache helpers (NSLock-protected) in `SessionCacheManager`: `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`.

## Dashboard

All sections use **selected-month data only** — no API calls. Card views defined inline in `DashboardViewController.swift`. Budget auto-detects number properties by scoring: "monthly budget"=100 → "budget"=90 → "limit"=80 → keyword=40, fallback to formula/rollup. Groups expenses by category relation ID.

## Filter System

`FilterPanelViewController` (presented modally from expense/income lists) → `FilterPanelViewModel` → `FilterEngine` (client-side AND-logic on `rawProperties`). Supports all property types. Relation properties load lazily from target DB. Post-filter search via `LocalSearchService.transactionMatchesSearch(_:query:)` — applied after FilterEngine, before grouping.

`FilterChipView` (28pt pill, `"PropertyName: value"`). Date range renders as `"Date: May 1 – May 31"`. Tapping × calls `viewModel.removeFilter(byId:)` or `viewModel.clearDateRange()`.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle` = `(AppTheme.currentMode == .dark ? .dark : .light)`. Toggle at `AppConstants.swift:105`: `static var currentMode: ThemeMode = .dark`. Warm cream/brown palette via `AppTheme.Colors`.

`RoleAssignmentCell` uses `accent` for selected segment tint and `buttonContent` for selected text (`DatabaseRoleAssignmentViewController.swift:373-382`). **Never hardcode `UIColor.white`** for segment text — use `AppTheme.Colors.buttonContent`.

## Persistence

- **UserDefaults** via `UserDefaultsManager` (shared): token, page ID/title.
- **`ColumnMappingService`** persists roles & column mappings to `UserDefaults` under `databaseMappings`/`columnMappings` keys.

## Settings — Health

`SetupMetadataService.loadHealthData()` fires async schema fetches on `viewDidAppear` — caches schemas and relation target DB IDs into `SessionCacheManager`. Two sections in Settings: **Notion Connection** (12 rows, read-only health) and **Setup Checklist** (16 checks: 12 required + 4 recommended). Colors: pass→income, warning→warning, fail→expense, unknown→textMuted. Checklist reads cached data exclusively; no API calls in computed properties.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Dead Code

- `SetupCompleteViewController.swift` — never instantiated
- `ViewController.swift` at project root — Xcode boilerplate
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Table views: `.plain` except `AddTransaction` and `Settings` which use `.insetGrouped`
- All UI programmatic; no storyboard segues or xibs
- `AGENTS.md` is gitignored (not version controlled)
