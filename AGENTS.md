# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no package managers, no CI. Deployment target 26.0. Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry & Navigation

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`.

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`.

## Gotchas

- **No `convertFromSnakeCase`**: Every `JSONDecoder()` uses default config. All `CodingKeys` must manually map snake_case keys (e.g. `"rich_text"` → `richText`).
- **Date-only strings**: Parse with `DateComponents` + `hour=12` local (`TransactionNormalizer.extractDate()`). `ISO8601DateFormatter` shifts to previous day in local tz.
- **Number parsing**: Strip commas via `replacingOccurrences(of: ",", with: "")` — do NOT replace commas with dots. Exception: `AddTransactionViewModel:127` replaces comma with dot for deep link amount parsing (handles European decimal).
- **PATCH returns updated page**: `updateTransaction` must return `NotionPage` from PATCH response. Parse in `buildUpdatedTransaction(from:updatedPage:)`.
- **Cache on create**: New transactions must be manually added to `SessionCacheManager` (`addExpense`/`addIncome`) via `lastCreatedPage`.
- **iOS 26 `performBatchUpdates` crash**: Avoid row count changes in `performBatchUpdates` blocks. Use only for height recalculation.
- **Budget over-budget check**: `Models/GroupedTransactionSection.swift:463` — use `pct > 1.0` (not `>= 1.0`).
- **Sub-1% formatting**: Use explicit `"<1%"` string. `maximumFractionDigits=0` rounds <0.5% to `"0%"`.
- **Mapping cell info icon recycling**: `MappingCell.configure()` must `infoButton.isHidden = true` at start.
- **Split metadata column type**: Filter `.appMetadata` for both `"rich_text"` and `"text"`.
- **Suggestions inline in title cell**: No `reloadData()`/`reloadRows()` for suggestion lifecycle — only `cell.updateSuggestions()`.
- **`tableView.reloadData()` not synchronous**: Month classification auto-select must fire in `cellForRowAt`, not `viewDidLoad`.

## Edit & Delete

Triggered from `TransactionDetailViewController`. Edit: `AddTransactionViewController` init with `editingTransaction`; VM `applyEditPrefill(columnMapping:)`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then cache `replaceExpense`/`replaceIncome`. Delete: confirmation → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then cache remove helpers.

## Cache

`SessionCacheManager` with `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`, `addExpense`, `addIncome`. Regroups by date after every mutation. NSLock-protected.

## Expense Category Suggestions

Up to 3 suggestion chips inline in the title `FormFieldCell`. 400ms debounce + immediate on `editingDidEnd`. Min 3 normalized chars. Hidden when: income tab, no title, no category field, unsupported category type, category already set, edit mode without title edit.

## Receipt Scanning

`ReceiptScanCoordinator`: file picker → OCR (Vision `VNRecognizeTextRequest` or PDFKit) → Gemini AI parsing. API key in Keychain via `GeminiKeychainService` (label `com.notra.gemini`). Default model `gemini-3.1-flash-lite`. Available: `gemini-2.0-flash`, `gemini-3.5-flash`, `gemini-3.1-flash-lite` (Settings picker). Fallback `ReceiptParserService` for local text-only extraction. `ReceiptReviewViewController` shows results before saving. If key missing, in-app alert → Keychain → file picker.

### Dashboard Plus Button (No Receipt Scan)

Dashboard FAB directly presents `AddTransactionViewController(initialRole: .expense)` — no action sheet, no receipt scan trigger from Dashboard. Scanning only via Settings → Scan Receipt.

## Multi-Person Receipt Split

`SplitPeopleStore` singleton (UserDefaults key `notraSplitPeople`) manages `SplitPerson(id, name)`.

`GeminiReceiptItem.sharedWith: [String]` holds person IDs. Items classified: `mine`, `shared`, `ignore`.

- Shared items → ONE combined `"<Merchant> Receipt"` expense with version 2 split metadata.
- All mine → one normal expense (no split metadata).
- Shared items must have ≥1 selected person; validation blocks save.
- `multiPersonSettlement` computed prop: mine full price → `myShare`; shared split equally among `1 + sharedWith.count` participants; tax proportional if `includeTaxProportionally`. Returns `(myShare, theyOwe, personOwes: [personId: amount])`.
- Split metadata version 2 (`buildMultiPersonSplitMetadataJSON`): contains `version: 2`, `split { enabled, status: "pending", type: "receiptMultiPerson", paidAmount, myShare, theyOwe, participants, items, inputs }`, `receipt { source, merchant, itemCount }`. Version 1 (`buildSplitMetadataJSON`) still exists but unused for new receipts.

### Bulk Actions (Receipt Review)

`BulkAssignmentMode` enum (`.none`, `.allMine`, `.allShared`) + `selectedBulkSharedPersonIds` owned by `ReceiptReviewViewModel`. `BulkActionsCell` renders 3 fill-equally buttons: [All Mine] [All Shared] [Clear].

- **Default**: no mode selected, chips hidden.
- **All Mine**: button gets accent highlight + checkmark. Sets all non-ignore items to `.mine`, clears `sharedWith`. Chips stay hidden.
- **All Shared**: button gets accent highlight + checkmark. Does NOT apply until person selected. Chips appear below buttons. Helper text "Select people to share all items with." while no one selected. Tapping a chip toggles it (checkmark + accent fill). Applying: all non-ignore items → `.shared` with selected person IDs.
- **Clear**: resets mode to `.none`, hides chips, resets non-ignore items to `.mine`.
- **Person chips**: hidden by default, visible only when `bulkMode == .allShared`. Selected chip: accent fill + "✓ Name". Unselected: `cardBackgroundAlt` fill + `textSecondary` + `border` border.
- **Button styling** (all 3 buttons): unselected = `cardBackgroundAlt`/`border`/`textMuted`; selected = `accent` fill+border/`buttonContent`/checkmark prefix. Clear is always unselected.

### Key Gotchas

- **Bottom inset**: `table.contentInset.bottom` must equal bottom bar height (`50 + 48 + 8 + 8 + 16`).
- **Empty sections**: `heightForHeaderInSection`/`heightForFooterInSection` return 0 when 0 rows to avoid gaps in `.insetGrouped`.
- **`displayMerchant`**: Guards `merchant != platform` to avoid "Walmart via Walmart".
- **Warning dedup**: Subtotal mismatch checks `warnings.contains` before appending.
- **Create button label**: `hasSharedItems` → "Create Split Expense"; personal-only → "Create 1 Expense".

## Split Details

Optional `expenseAppMetadataProperty` (Text/rich_text column) stores `SplitMetadata` JSON. Decodes old `expenseSplitDetailsProperty` key. Skipped from Add Transaction form. Works unmapped with warning toast.

SplitMethodType: `splitEqually`, `exactAmounts`, `percent`, `shares`, `adjustment`. Legacy `"50/50"` → `splitEqually`, `"Custom Amount"` → `exactAmounts` via `fromLegacy()`.

- **UI**: 2x2 method chip grid in `SplitDetailCell`. Bottom stack auto-collapses hidden subviews.
- **List display**: `paidAmountLabel` physically removed from `contentStack.arrangedSubviews` for non-split, re-added for split only.
- **Info sheet**: `SplitHelpViewController` presented `.overFullScreen` with cross-dissolve.

## Dashboard

All sections use selected-month data only — no API calls. Hierarchy: Hero → Overview → Monthly Status → Monthly Budget (tappable, push ExpenseList) → Recent Activity → Quick Checks → Explore. `sectionSpacing = 28`. Budget auto-detects number properties in category DB by keyword scoring; groups expenses by category relation ID.

## Filter System

`FilterPanelViewController` (modal) → `FilterPanelViewModel` → `FilterEngine` (AND-logic on `rawProperties`). Post-filter search via `LocalSearchService`. `.between` excluded from date properties; From/To inline date pickers instead.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle = (AppTheme.currentMode == .dark ? .dark : .light)`. Default mode: `.dark` (`Helpers/AppConstants.swift:106`). Warm cream/brown palette. Never hardcode `UIColor.white` for segment text — use `AppTheme.Colors.buttonContent`.

## Persistence

- **UserDefaults** via `UserDefaultsManager`: token, page ID/title, Gemini model name.
- **`ColumnMappingService`**: JSON under `databaseMappings`/`columnMappings` keys.
- **ColumnMapping**: custom `CodingKeys` — decodes old `expenseSplitDetailsProperty` into `expenseAppMetadataProperty`; encodes only new key.
- **Keychain**: `GeminiKeychainService` stores Gemini API key.

## Architecture Notes

- **AnalyticsViewController**: ~3000 lines, all chart views inline. USD hardcoded. Top 6 + "Other" in donut. Zero API calls.
- **NotionService**: Two API versions — standard `2022-06-28`, data source APIs hardcode `2025-09-03`.
- **NotionDataFetcher**: Three-tier fallback: data source API → search → direct DB query. `page_size=100`.
- **CategoryParserService**: First 100 rows only (no pagination).
- **TransactionNormalizer**: Amounts `abs()`'d. Deduplicates by page id. Relation resolution via `relationLookupMap`.
- **DatabaseDiscoveryService**: Searches ALL accessible databases via `POST /search`. Adds `"title"` property if missing.
- **NotionService.fetchTopLevelPages**: Only workspace-level pages (`parent.type == "workspace"`).
- **DynamicFormValue.isEmpty**: For `.checkbox`, always `false`.
- **Table views**: `.plain` except `AddTransaction`, `Settings`, `FilterPanel`, `ReceiptReview`, `SplitTracker` (`.insetGrouped`).

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`, `[ReceiptScan]`, `[ReceiptImport]`, `[ReceiptExtraction]`, `[GeminiReceiptParser]`, `[ReceiptReview]`, `[ReceiptValidation]`

## Dead Code

- `SetupCompleteViewController.swift`, `ViewController.swift` — never instantiated
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Use `AppTheme.Fonts`, `AppTheme.CornerRadius`, `AppTheme.Shadow`, `AppTheme.styleNavigationBar()` for consistency
- `AGENTS.md` is gitignored (not version controlled)
