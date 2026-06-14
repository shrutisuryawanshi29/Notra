# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no package managers, no CI. Deployment target 26.0, Swift 5.0. Dev team `85R4T7NRSX`, bundle `com.loml.Notra`.

## Entry & Navigation

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`.

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

## ⚠️ Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`.

## Decoding & Parsing Gotchas

- **No `convertFromSnakeCase`**: Every `JSONDecoder()` uses default config. All `CodingKeys` must manually map snake_case keys (e.g. `"rich_text"` → `richText`).
- **Date-only strings**: Parse with `DateComponents` + `hour=12` local (`TransactionNormalizer.extractDate()`). `ISO8601DateFormatter` shifts to previous day in local tz.
- **Number parsing**: Strip commas via `replacingOccurrences(of: ",", with: "")` — do NOT replace commas with dots. Exception: `AddTransactionViewModel:324` replaces comma with dot for deep link amount parsing (handles European decimal).
- **Split metadata column type**: Filter `.appMetadata` for both `"rich_text"` and `"text"`.

## API & Cache Gotchas

- **PATCH returns updated page**: `updateTransaction` must return `NotionPage` from PATCH response. Parse in `buildUpdatedTransaction(from:updatedPage:)`.
- **Cache on create**: New transactions must be manually added to `SessionCacheManager` (`addExpense`/`addIncome`) via `lastCreatedPage`.
- **`SessionCacheManager`**: NSLock-protected, regroups by date after every mutation. Methods: `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`, `addExpense`, `addIncome`.

## UIKit Gotchas

- **iOS 26 `performBatchUpdates` crash**: Avoid row count changes in `performBatchUpdates` blocks. Use only for height recalculation.
- **`tableView.reloadData()` not synchronous**: Month classification auto-select must fire in `cellForRowAt`, not `viewDidLoad`.
- **Mapping cell info icon recycling**: `MappingCell.configure()` must `infoButton.isHidden = true` at start.
- **Bottom inset**: `table.contentInset.bottom` must equal bottom bar height (`50 + 48 + 8 + 8 + 16`).
- **Empty sections**: `heightForHeaderInSection`/`heightForFooterInSection` return 0 when 0 rows to avoid gaps in `.insetGrouped`.
- **Table views**: `.plain` except `AddTransaction`, `Settings`, `FilterPanel`, `ReceiptReview`, `SplitTracker`, `SplitTrackerPersonDetail` (`.insetGrouped`).
- **Suggestions inline in title cell**: No `reloadData()`/`reloadRows()` for suggestion lifecycle — only `cell.updateSuggestions()`.

## Budget Gotchas

- **Over-budget check**: `Models/GroupedTransactionSection.swift:463` — use `pct > 1.0` (not `>= 1.0`).
- **Sub-1% formatting**: Use explicit `"<1%"` string. `maximumFractionDigits=0` rounds <0.5% to `"0%"`.

## Edit & Delete

Triggered from `TransactionDetailViewController`. Edit: `AddTransactionViewController` init with `editingTransaction`; VM `applyEditPrefill(columnMapping:)`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH), then cache `replaceExpense`/`replaceIncome`. Delete: confirmation → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then cache remove helpers.

## Expense Category Suggestions

Up to 3 suggestion chips inline in the title `FormFieldCell`. 400ms debounce + immediate on `editingDidEnd`. Min 3 normalized chars. Hidden when: income tab, no title, no category field, unsupported category type, category already set, edit mode without title edit.

## Receipt Scanning

`ReceiptScanCoordinator`: file picker → OCR (Vision `VNRecognizeTextRequest` or PDFKit) → Gemini AI parsing. API key in Keychain via `GeminiKeychainService` (label `com.notra.gemini`). Default model `gemini-3.1-flash-lite`. Available: `gemini-2.0-flash`, `gemini-3.5-flash`, `gemini-3.1-flash-lite` (Settings picker). Fallback `ReceiptParserService` for local text-only extraction. `ReceiptReviewViewController` shows results before saving. If key missing, in-app alert → Keychain → file picker.

Dashboard FAB directly presents `AddTransactionViewController(initialRole: .expense)` — no receipt scan trigger from Dashboard. Scanning only via Settings → Scan Receipt.

## Multi-Person Receipt Split

`SplitPeopleStore` singleton (UserDefaults key `notraSplitPeople`) manages `SplitPerson(id, name)`. IDs are deterministic via `stablePersonId(from:)` — lowercase, no diacritics, spaces→hyphens, strip unsupported chars. `load()` auto-migrates old UUID IDs to stable name-based IDs.

`GeminiReceiptItem.sharedWith: [String]` holds person IDs. Items classified: `mine`, `shared`, `ignore`.

- Shared items → ONE combined `"<Merchant> Receipt"` expense with version 2 split metadata.
- All mine → one normal expense (no split metadata).
- Shared items must have ≥1 selected person; validation blocks save.
- `multiPersonSettlement` computed prop: mine full price → `myShare`; shared split equally among `1 + sharedWith.count` participants; tax proportional if `includeTaxProportionally`. Returns `(myShare, theyOwe, personOwes: [personId: amount])`.
- Version 2 split metadata (`buildMultiPersonSplitMetadataJSON`): `{ version: 2, split { enabled, status: "pending", type: "receiptMultiPerson", paidAmount, myShare, theyOwe, participants, items, inputs }, receipt { source, merchant, itemCount } }`. Version 1 (`buildSplitMetadataJSON`) exists but unused for new receipts.
- Manual add uses centralized `calculateManualSplit()` in `AddTransactionViewModel.swift` — single source of truth for v2 metadata.

### Split Tracker

`SplitTrackerViewModel.buildGroups(from:)` groups participants by `stablePersonId(name)`. Display name resolution: prefers participant name from metadata → resolves via `SplitPeopleStore.getPersonByStableId()` → converts stable ID to readable title (`"sandy"` → `"Sandy"`) → `"Unknown person"`. `SplitTrackerViewController.viewWillAppear` reloads from cache.

Person detail screen (`SplitTrackerPersonDetailViewController`):
- Compact header: name + pending owed + settled + entry count (no duplicate giant name)
- Transaction cards: title + amount top row, date • category, split context (`"Paid: $X • Their share: $Y"`), compact Pending chip (warning/gold) + Settle button (income/green, right-aligned)
- Edit from detail: wired via `detailVC.onEdit` → `AddTransactionViewController` in edit mode → cache update + reload on success
- Settlement: PATCH only participant status in Split Details JSON, no income created

### Bulk Actions (Receipt Review)

`BulkAssignmentMode` enum (`.none`, `.allMine`, `.allShared`) + `selectedBulkSharedPersonIds` owned by `ReceiptReviewViewModel`. Default: no mode, chips hidden.
- **All Mine**: Sets all non-ignore items to `.mine`, clears `sharedWith`. Chips stay hidden.
- **All Shared**: Does NOT apply until person selected. Chips appear below buttons. Tapping a chip toggles selection. Applying: all non-ignore items → `.shared` with selected person IDs.
- **Clear**: resets mode to `.none`, hides chips, resets non-ignore items to `.mine`.
- **Button styling**: unselected = `cardBackgroundAlt`/`border`/`textMuted`; selected = `accent`/`buttonContent`/checkmark prefix (`✓`). Clear always unselected.
- **`displayMerchant`**: Guards `merchant != platform` to avoid "Walmart via Walmart".
- **Create button label**: `hasSharedItems` → "Create Split Expense"; personal-only → "Create 1 Expense".

## Split Details

Optional `expenseAppMetadataProperty` (Text/rich_text column) stores `SplitMetadata` JSON. Decodes old `expenseSplitDetailsProperty` key. Skipped from Add Transaction form. Works unmapped with warning toast.

### Version 2 (manual participant) types

When people are selected, the centralized `calculateManualSplit()` in `AddTransactionViewModel.swift` computes everything and caches `lastManualSplitResult`. All paths (recalculate, build JSON, cache) read from this single result.

- `manualEqual` → Equal split, each `myShare = paid / (1 + count)`
- `manualPercent` → Percent split, `myShare = paid * myPercent / 100` (or `theyOwe = paid * theirPercent / 100` depending on `entryMode`)
- `manualCustom` → Exact amount split, `theyOwe = customAmount` (or `myShare = customAmount`)
- `receiptMultiPerson` → Receipt scan multi-person

Participant owes for manualPercent/manualCustom: `theyOwe / selectedCount` (equal split of theyOwe among selected people).

### Display mapping

`SplitMetadata.displayTypeName` and `SplitMethodType.fromLegacy()` now handle all v2 types:
- `manualEqual` → `"Equal"` / `.splitEqually`
- `manualPercent` → `"Percent"` / `.percent`
- `manualCustom` → `"Exact amount"` / `.exactAmounts`
- `receiptMultiPerson` → `"Multi-Person Split"`

### Save flow

In `saveTransaction()`:
1. VM calls `recalculateSplit()` → `calculateManualSplit()` → stores `lastManualSplitResult`
2. Reads `splitResult.myShare` → sets Notion Amount
3. Reads `splitResult.splitDetailsJSON` → sets Notion Split Details rich_text
4. VC's `buildUpdatedTransaction`/`buildNewTransaction` reads `viewModel.lastManualSplitResult` for cache object

### Edit & Legacy Upgrade

`isLegacySplitWithoutParticipants` detects v1 splits with no participants. When editing and selecting a person, the split is upgraded to v2 metadata (version 2, type matching the selected method, participants array). An amber helper label `"Select a person to replace legacy split person."` appears above the people chips.

### JSON Serialization Gotcha

`buildUpdatedJSON()` in `GroupedTransactionSection.swift` must convert `SplitInputs`, `[SplitItem]`, and `ReceiptScanMetadata` structs to `[String: Any]` dictionaries before passing to `JSONSerialization`. Swift Codable structs passed as `Any` cause `__SwiftValue` crash.

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
- **`DynamicFormValue.isEmpty`**: For `.checkbox`, always `false`.

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseListViewModel]`, `[IncomeListViewModel]`, `[ExpenseFilter]`, `[IncomeFilter]`, `[ReceiptScan]`, `[ReceiptImport]`, `[ReceiptExtraction]`, `[GeminiReceiptParser]`, `[ReceiptReview]`, `[ReceiptValidation]`, `[ManualSplit]`, `[ManualSplitCalc]`, `[ManualSplitSave]`, `[EditSplit]`, `[SplitTracker]`, `[SplitTrackerDetail]`, `[SplitDetailsParser]`

## Dead Code

- `SetupCompleteViewController.swift`, `ViewController.swift` — never instantiated
- `Main.storyboard` — unused (SceneDelegate builds UI in code)

## Style

- Use `AppTheme.Fonts`, `AppTheme.CornerRadius`, `AppTheme.Shadow`, `AppTheme.styleNavigationBar()` for consistency.
- `AGENTS.md` is gitignored (not version controlled).
