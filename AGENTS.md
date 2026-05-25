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

## Add Transaction — Month Classification

`tableView.reloadData()` is not synchronous — `didAutoSelectMonthClassification` can fire before cells exist. **Do not** move auto-select to `viewDidLoad`. Fix in `cellForRowAt` (lines 536-541): after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match.

## Edit & Delete

**Edit** — `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)` → `fieldValues` from `rawProperties`. Save → `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then `onEditComplete` → `replaceExpense`/`replaceIncome`.

**Delete** — confirmation alert → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then `removeExpense(byPageId:)`/`removeIncome(byPageId:)`.

Cache helpers in `SessionCacheManager`: `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)` — update flat array by page ID and re-group sections.

## Dashboard

All sections use **only selected-month data** — no API calls, no all-time loading.

| Section | View |
|---|---|
| **This Month Status** | `StatusCardView` — icon + color-coded message + footer counts |
| **Monthly Budget** | `BudgetCardView` → 2-col grid of `BudgetCategoryCardView` with `CircularProgressView` ring (62pt) |
| **Recent Activity** | `ActivityCardView` → `ActivityRowView`: dot + title + "category · rel date" + +/- amount (latest 5, date desc, deduped by page ID) |
| **Quick Checks** | `QuickChecksCardView` → `QuickCheckRowView`: icon + label + value |

Budget auto-detects number properties by score ("monthly budget"=100 → "budget"=90 → "limit"=80 → keyword=40), fallback to formula/rollup. Groups selected-month expenses by category relation ID.

All card views defined inline in `DashboardViewController.swift` (not separate files).

## Analytics

`AnalyticsViewController` via `AnalyticsViewModel`. View modes: overview, categories, trends. Time ranges: this month, 3m, 6m, 12m, all time.

## Filter System

- Client-side AND-logic on `rawProperties` (no API calls)
- `.pageSheet` presentation; relation properties load lazily via `RelationResolverService`
- Excluded from UI: `url`, `email`, `phone_number`, `formula`, `rollup`, `created_time`, `created_by`, `last_edited_time`, `last_edited_by`, `unique_id`, `verification`

## Deep Links

`notra://add-expense` / `notra://add-income` — optional query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist sets system default. `window.overrideUserInterfaceStyle` follows `AppTheme.currentMode` (`SceneDelegate.swift:40`). Toggle at `AppConstants.swift:105`:
```swift
static var currentMode: ThemeMode = .dark  // .light restores original appearance
```

Warm cream/brown palette via `AppTheme.Colors` (all programmatic).

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
| `Services/SetupStateManager.swift` | Startup routing, state check, reset |
| `Helpers/AppConstants.swift` | API config, `AppTheme` (warm cream/brown palette), spacing, shadows, fonts |

## Dead Code

- `SetupCompleteViewController.swift` in `Controllers/` — never instantiated
- `ViewController.swift` at project root — unused Xcode boilerplate
- `Main.storyboard` in `Base.lproj` — exists but unused (SceneDelegate builds UI in code)

## Style

- Table views: `.plain` (not `.insetGrouped`), except AddTransaction which uses `.insetGrouped`
- All UI programmatic; no storyboard segues or xibs
- `AGENTS.md` gitignored (not version controlled)
