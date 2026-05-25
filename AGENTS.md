# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI (no storyboards), MVVM, no deps.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no CocoaPods/SPM, no CI. Deployment target 26.4 (project 26.0). Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`. iPhone + iPad.

## Entry Flow

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` → one of:
1. `TokenEntryViewController` (no token)
2. `PagePickerViewController` (no page)
3. `DatabaseRoleAssignmentViewController` (no roles)
4. `ColumnMappingViewController` (no mappings)
5. `DashboardViewController` (all done)

`DashboardViewModel` is the only screen calling Notion API directly; others read from `SessionCacheManager`.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`. Fix when ready.

## Add Transaction — Month Classification Lifecycle

Month Classification auto-defaults from transaction date. `tableView.reloadData()` is **not** synchronous, so `didAutoSelectMonthClassification` fires before cells exist. Do **not** move auto-select to `viewDidLoad`. Fix in `cellForRowAt` (AddTransactionViewController.swift:536-541): after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match.

## Edit & Delete

**Edit** — `AddTransactionViewController` init with `editingTransaction`; ViewModel calls `applyEditPrefill(columnMapping:)` → `fieldValues` from `rawProperties`. Critical: `cellForRowAt` must read back from `fieldValues` after cell config (text → `stringValue`/`numberValue`, picker → `selectValue`/`multiSelectValues`, switches → `boolValue`). Save → `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then `onEditComplete` → `replaceExpense`/`replaceIncome`.

**Delete** — confirmation alert → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then `removeExpense(byPageId:)`/`removeIncome(byPageId:)`.

Cache helpers in `SessionCacheManager`: `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)` — update flat array by page ID and re-group sections.

## Dashboard

All sections use **only selected-month data** — no API calls, no all-time loading.

| Section | Data Source | View |
|---|---|---|
| **This Month Status** | `statusInfo` → `DashboardStatusInfo` | `StatusCardView` — icon + color-coded message + footer counts |
| **Monthly Budget** | `budgetCategories` + `budgetSummary` from `computeBudgetUtilization()` | `BudgetCardView` → 2-col grid of `BudgetCategoryCardView` with `CircularProgressView` ring (62pt) |
| **Recent Activity** | `recentTransactions` — latest 5, date desc, deduped by page ID | `ActivityCardView` → `ActivityRowView`: dot + title + "category · rel date" + +/- amount |
| **Quick Checks** | `largestExpense`, `mostUsedCategory`, `uncategorizedCount` | `QuickChecksCardView` → `QuickCheckRowView`: icon + label + value |

Actions: 3 full-width buttons → Expense List, Income List, Analytics. Settings via nav bar gear.

Budget auto-detects number properties by score ("monthly budget"=100 → "budget"=90 → "limit"=80 → keyword=40), fallback to formula/rollup. Groups selected-month expenses by category relation ID. Summary: "N over budget · N close · N on track".

## Analytics

`AnalyticsViewController` via `AnalyticsViewModel`. View modes: overview, categories, trends. Time ranges: this month, 3m, 6m, 12m, all time.

## Filter System

- Client-side AND-logic on `rawProperties` (no API calls)
- `.pageSheet` presentation; relation properties load lazily via `RelationResolverService`
- Excluded from UI: `url`, `email`, `phone_number`, `formula`, `rollup`, `created_time`, `created_by`, `last_edited_time`, `last_edited_by`, `unique_id`, `verification`
- Summary bar: "Filtered Total: $X · N items" when active

## Deep Links

`notra://add-expense` / `notra://add-income` — optional query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`.

## Light Mode

Forced: `UIUserInterfaceStyle: Light` in Info.plist + `window.overrideUserInterfaceStyle = .light` in SceneDelegate.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Key Files

| File | Role |
|---|---|
| `Services/NotionService.swift` | API client (`api.notion.com/v1`, version `2022-06-28`); `trashPage()` via PATCH `in_trash: true` |
| `Services/NotionDataFetcher.swift` | DB row fetching: data_source API → search → direct query fallback |
| `Services/SessionCacheManager.swift` | Thread-safe cache (NSLock); `replaceExpense`/`replaceIncome`/`remove*(byPageId:)` |
| `Services/ColumnMappingService.swift` | Persist/load roles & mappings to UserDefaults |
| `Services/TransactionInsertService.swift` | POST `/pages`; `updateTransaction()` via PATCH |
| `Services/TransactionNormalizer.swift` | Notion API pages → `NormalizedTransaction` |
| `Services/FilterEngine.swift` | Client-side AND-logic on `rawProperties` |
| `Services/CategoryParserService.swift` | Category from select/multi-select/relation/text |
| `Services/DatabaseDiscoveryService.swift` | Auto-discovers accessible Notion databases |
| `Services/RelationResolverService.swift` | Lazily resolves relation options from target DB |
| `Services/UserDefaultsManager.swift` | Typed `UserDefaults` wrapper |
| `Services/SetupStateManager.swift` | Startup routing, state check, reset |
| `Helpers/AppConstants.swift` | API config, `AppTheme` (warm cream/brown palette), spacing, shadows, fonts |

## Style & Quirks

- Light mode forced everywhere; warm cream/brown palette via `AppTheme`
- Table views: `.plain` (not `.insetGrouped`), except Settings
- All UI programmatic. `Main.storyboard` exists in `Base.lproj` but **unused** (SceneDelegate builds window/nav in code)
- `Extensions/` directory empty
- `SetupCompleteViewController.swift` in `Controllers/` — **dead code**, never called
- `ViewController.swift` at project root — unused Xcode boilerplate
- `AGENTS.md` gitignored (not version controlled)
