# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI, MVVM, no dependencies.

## Build

```bash
xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

No tests, no CocoaPods/SPM, no CI. Deployment target Debug=26.0, Release=26.4. Swift 5.0. Dev team `85R4T7NRSX`. Bundle `com.loml.Notra`.

## Entry & Navigation

`SceneDelegate.swift` → `SetupStateManager.nextRequiredScreen()` routes: `TokenEntry` → `PagePicker` → `DatabaseRoleAssignment` → `ColumnMapping` → `Dashboard`.

Only `DashboardViewModel` calls the Notion API directly; setup screens read from `SessionCacheManager`.

## Known Bug — Do Not Fix

`SceneDelegate.swift:152` returns `DatabaseRoleAssignmentViewController()` for `.columnMapping` instead of `ColumnMappingViewController()`.

## Fixed Bugs (don't reintroduce)

- **NotionPropertyValue missing CodingKeys**: `NotionPropertyValue.richText` was always `nil` because the struct had no `CodingKeys` mapping the Notion API's `"rich_text"` (snake_case) to `richText` (camelCase). Every `JSONDecoder()` in the app uses default config (no `.convertFromSnakeCase`). Fix: added `CodingKeys` with `case richText = "rich_text"`, `case multiSelect = "multi_select"`, `case phoneNumber = "phone_number"`. This caused `extractSplitMetadata()` to always return `nil`, so split metadata was never parsed from saved Notion pages.

- **Month classification**: `tableView.reloadData()` isn't synchronous → `didAutoSelectMonthClassification` fires before cells exist. Fix in `cellForRowAt`: after configuring `.relation` cell, check `viewModel.fieldValues[field.propertyName]` and set button title from match. Do NOT move to `viewDidLoad`.
- **Date-shift in edits**: `applyEditPrefill()` using `ISO8601DateFormatter` for date-only strings parses midnight UTC → previous day in local tz. Use `DateComponents` with `hour=12` local (`TransactionNormalizer.extractDate()`).
- **Number parsing**: Strip commas (`replacingOccurrences(of: ",", with: "")`), not replace commas with dots.
- **Stale rawProperties**: `updateTransaction` must return `NotionPage` from PATCH response so re-edit shows fresh values. Parse response in `buildUpdatedTransaction(from:updatedPage:)`.
- **Cache gap**: New transactions must be added to `SessionCacheManager` (`addExpense`/`addIncome`) in `showSuccess()` via `lastCreatedPage`.
- **Edit mode keyboard flicker**: Suggestion chips embedded in `FormFieldCell`, not a separate table row. No `tableView.reloadData()`/`reloadRows()` for suggestion lifecycle — only `cell.updateSuggestions()`. Re-enabled via `hasUserEditedTitleForSuggestions`.
- **iOS 26 performBatchUpdates crash**: `tableView.reloadRows()` wraps in `performBatchUpdates` on iOS 26, conflicting with `UIDatePicker.compact`. Fix: suggestions in title cell, only `performBatchUpdates(nil)` for height recalculation — no row count changes.
- **Placeholder disappears**: Suggestions `contentStack` taller than cell height compresses text field below 30pt. `performBatchUpdates(nil)` recalculates height.
- **Single match suppressed**: Two-rule gate: `totalMatched >= 2 && confidence >= 0.5` OR `totalMatched == 1 && confidence >= 0.5 && matchStrength >= .strong`.
- **Budget 100%**: `GroupedTransactionSection.swift:87`: use `pct > 1.0` (not `>= 1.0`) for overBudget.
- **Sub-1% format**: `privateFormatPercent` — use `<1%` (was `maximumFractionDigits=0` rounding <0.5% to `0%`).
- **Mapping cell info icon on recycled cells**: `MappingCell.configure()` must explicitly `infoButton.isHidden = true` at start (not just `false` for `.appMetadata`). Otherwise recycled `.appMetadata` cells keep the icon visible on standard rows.
- **Split Details filter misses `text` type**: Column picker filter for `.appMetadata` must accept both `"rich_text"` and `"text"` since the Notion API may return either.
- **Mapping picker uses sheet, not alert**: `showColumnPicker` presents `ColumnPickerViewController` (modal sheet), not `UIAlertController`. Do not revert to action sheet — it looks like a confirm dialog when only one option exists.
- **Split metadata parsing**: `extractSplitPaidFromMetadata()` only extracted `paidAmount`. Use `extractSplitMetadata()` which returns `SplitMetadata?` with `myShare`, `theyOwe`, `type`, `status`, `splitWith`. `NormalizedTransaction.isSplit` now checks `splitMetadata?.enabled == true`. `effectiveAmount` reads `split.myShare` first. `reimbursementAmount` reads `split.theyOwe` first.
- **Split status hardcoded**: `TransactionDetailViewController.setupSplitDetails()` had `"Pending"` hardcoded. Now reads `transaction.splitStatus?.capitalized` and `transaction.splitType`.
- **Split status not preserved on edit**: `buildSplitMetadataJSON` always set `status: "pending"`. Now uses `splitStatus` stored property which preserves the original status from JSON on edits.
- **Raw Split Details JSON in detail screen**: `setupDetails()` looped all `rawProperties` but never excluded `expenseAppMetadataProperty`. Raw JSON `{"version":1,"split":{...}}` appeared as a generic field row. Fix: add `expenseAppMetadataProperty` to `mappedColumnNames` exclusion set in `TransactionDetailViewController.init`.
- **Detail split section plain/left-aligned**: Old `setupSplitDetails()` used vertical `DetailRowView` stack with empty right side. Now uses two-column grid of border stat tiles via `makeStatTile(label:value:)`. Rows: Counted/Paid, Owed/Status. Bottom row: Method, Split with.
- **Expense list split text truncated**: `paidAmountLabel` defaulted to 1 line, `.byTruncatingTail`. Now `numberOfLines = 0`, `.byWordWrapping`, two-line format: `"Split · 50/50\nPaid $25.00 · Owed $12.50"`.
- **Expense list hidden-label residual gap**: `paidAmountLabel` used direct constraints — `isHidden = true` did not collapse its frame. Non-split cards had ~15pt dead space from font line height. Fix: `contentStack` UIStackView (vertical, `.fill`) with title + paidAmountLabel as arranged subviews. Stack auto-collapses hidden subviews. categoryContainer kept outside stack, top-anchored to `contentStack.bottom + 8`. Card padding increased to 16pt top/bottom.
- **Filtered Total footer covers last row**: Both `ExpenseListViewController` and `IncomeListViewController` had no `contentInset.bottom`. Last cell flush against summary separator. Fix: `contentInset.bottom = 60`, `scrollIndicatorInsets.bottom = 60`.

## Edit & Delete

Triggered from `TransactionDetailViewController`. Edit: `AddTransactionViewController` init with `editingTransaction`; ViewModel `applyEditPrefill(columnMapping:)`. Save via `TransactionInsertService.updateTransaction(pageId:)` (PATCH returns updated `NotionPage`), then cache `replaceExpense`/`replaceIncome`. Delete: confirmation → `NotionService.trashPage(pageId:)` (PATCH `in_trash: true`), then cache remove helpers.

## Cache (NSLock-protected)

`SessionCacheManager` with `replaceExpense`, `replaceIncome`, `removeExpense(byPageId:)`, `removeIncome(byPageId:)`, `addExpense`, `addIncome`. Regroups by date after every mutation.

## Expense Category Suggestions

Up to 3 suggestion chips inline in the title `FormFieldCell` (not a separate row). No Notion calls, no auto-apply. 400ms debounce + immediate on `editingDidEnd`. Min 3 normalized chars. Hidden when: income tab, no title, no category field, unsupported category type, category already set, edit mode without title edit. `performBatchUpdates(nil)` only for height — no row insert/delete/reload.

## Split Details Column (`expenseAppMetadataProperty`)

Optional Text column in Expense DB for JSON metadata (split info). Notion API type is `rich_text`; filter must accept both `"rich_text"` and `"text"`. User-facing type name is "Text". Backward-compatible `CodingKeys`: decodes old `expenseSplitDetailsProperty` key. Mapped column skipped from the Add Transaction form (`buildFields`). Can be unmapped — split works in-session with warning toast. `TransactionInsertService.buildPropertyPayload` handles rich-text Notion format. Main Amount column always stores my share/effective amount.

`SplitMetadata` struct (Codable) holds `enabled`, `paidAmount`, `myShare`, `theyOwe`, `type`, `status`, `splitWith`, `inputs`. `SplitInputs` holds method-specific values (`myPercent`, `theirPercent`, `myShares`, `theirShares`, `adjustmentAmount`, `adjustmentMode`, `entryMode`). `SplitMethodType` enum: `splitEqually`, `exactAmounts`, `percent`, `shares`, `adjustment`. Backward compat: `"50/50"` maps to `splitEqually`, `"Custom Amount"` maps to `exactAmounts` via `SplitMethodType.fromLegacy()`.

`SplitCalculator.calculate(paidAmount:method:myShareExact:theyOweExact:myPercent:theirPercent:myShares:theirShares:adjustmentAmount:adjustmentMode:)` returns `SplitResult` with `myShare`, `theyOwe`, `inputs`, `type`. Supports both entry modes for exact (`myShare`/`theyOwe`) and percent (`myPercent`/`theirPercent`), and both adjustment directions (`extraIPay`/`extraTheyPay`). Validation via `SplitCalculator.validate()`.

`SplitMetadata` JSON structure stores `inputs` dict: `{myShare, myPercent, theirPercent, myShares, theirShares, adjustmentAmount, adjustmentMode, entryMode}`. `SplitMethodType` raw values are the JSON type strings. Old `"50/50"` and `"Custom Amount"` types parsed on read.

**Split method chips**: Visible chip buttons in 3-row wrapping grid layout inside `SplitDetailCell`. No dropdown/action sheet. Selected chip filled with `expense` color + `buttonContent` text; unselected has muted text + `border` border. Tapping a chip calls `onMethodChange`, triggers ViewModel recalculation, and rebuilds entry mode + input fields.

**Entry mode toggle**: `UISegmentedControl` for exact (My share / They owe) and percent (My % / Their %) methods. Hidden for other methods. Changes call `onEntryModeChange` to update `splitEntryMode` in ViewModel.

**Adjustment direction**: Two side-by-side chip buttons ("Extra I pay" / "Extra they pay") inside the adjustment input area. `onAdjustmentModeChange` callback updates `splitAdjustmentMode` in ViewModel.

**Summary tiles**: Two side-by-side `SummaryTileView` cards (50/50 split) showing "Your share" (expense-colored) and "They owe" (primary text). Helper text below: "Your share is used for spending, budgets, and analytics."

**Info sheet**: `SplitHelpViewController` presented as `.overFullScreen` with cross-dissolve, showing a centered card with descriptions of all 5 methods + "Got it" button. Dismiss on overlay tap.

**Detail screen display**: Two-column grid of border stat tiles via `makeStatTile(label:value:)` in `TransactionDetailViewController`. Rows: Counted | Paid, Owed | Status. Bottom: Method (via `displayTypeName`), Split with.

**Expense list display**: Two-line format `"Split · {Method}\nPaid $X.XX · Owed $X.XX"` in `FinanceCell.paidAmountLabel`. Method name from `splitMetadata.displayTypeName`. Multiline, word-wrapping, hidden via stack auto-collapse for non-split.

## Dashboard

All sections use selected-month data only — no API calls. Section hierarchy: Hero → Overview (Spent/Income/Balance) → Monthly Status → Monthly Budget (tappable, push ExpenseList) → Recent Activity → Quick Checks → Explore. `sectionSpacing = 28`. FAB: full-screen (`modalPresentationStyle = .fullScreen`). Budget auto-detects number properties in category DB by keyword scoring; groups expenses by category relation ID.

## Filter System

`FilterPanelViewController` (modal) → `FilterPanelViewModel` → `FilterEngine` (AND-logic on `rawProperties`). Post-filter search via `LocalSearchService.transactionMatchesSearch`. `.between` excluded from date properties; date pickers handled by separate From/To inline date pickers.

## Deep Links

`notra://add-expense` / `notra://add-income` — query params: `title`, `amount`, `date` (yyyy-MM-dd), `notes`. Parsed in `SceneDelegate.handleDeepLink()`.

## Theme

`UIUserInterfaceStyle: Light` in Info.plist. `window.overrideUserInterfaceStyle = (AppTheme.currentMode == .dark ? .dark : .light)`. Default mode: `.dark` (`AppConstants.swift:105`). Warm cream/brown palette. Never hardcode `UIColor.white` for segment text — use `AppTheme.Colors.buttonContent`.

## Persistence

- **UserDefaults** via `UserDefaultsManager`: token, page ID/title.
- **`ColumnMappingService`** persists roles & column mappings under `databaseMappings`/`columnMappings` keys (JSON).
- **ColumnMapping**: custom `CodingKeys` — decodes old `expenseSplitDetailsProperty` into `expenseAppMetadataProperty`; encodes only the new key.

## Architecture Notes

- **AnalyticsViewController**: ~3000 lines — all chart views inline in the same file. USD hardcoded. Top 6 + "Other" in donut chart. Zero API calls.
- **NotionService**: Two API versions — standard uses `2022-06-28` (`AppConstants.API.notionVersion`), data source APIs hardcode `2025-09-03`.
- **NotionDataFetcher**: Three-tier fallback: (1) data source API → (2) search → (3) direct DB query. Pagination (page_size=100).
- **CategoryParserService**: First 100 rows only (no pagination). Relation names show `"Loading..."` until resolved.
- **TransactionNormalizer**: Amounts are `abs()`'d. Deduplicates by page id. Relation category resolution uses `relationLookupMap`. `extractSplitMetadata()` parses full split JSON from the mapped metadata column into `SplitMetadata`.
- **DatabaseDiscoveryService**: Searches ALL accessible databases via `POST /search` (not restricted to a page). Manually adds `"title"` property if missing.
- **NotionService.fetchTopLevelPages**: Only workspace-level pages (`parent.type == "workspace"`).
- **DynamicFormValue.isEmpty**: For `.checkbox`, always `false`.
- **FinanceCell** (`Controllers/FinanceCell.swift`): Amount label max width 130pt. Shared for expense/income lists. Uses `contentStack` (UIStackView, vertical, `.fill`) with `titleLabel` + `paidAmountLabel` as arranged subviews. `categoryContainer` is outside the stack (needs `lessThanOrEqualTo` trailing for pill sizing), top-anchored to `contentStack.bottom + 8`. Stack auto-collapses hidden `paidAmountLabel` for non-split expenses — no residual gap. `setCustomSpacing(6, after: titleLabel)` for split, reset to 0 when not split. `prepareForReuse` resets all text, hidden state, and custom spacing.

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

- Table views: `.plain` except `AddTransaction`, `Settings`, and `FilterPanel` which use `.insetGrouped`
- Use `AppTheme.Fonts`, `AppTheme.CornerRadius`, `AppTheme.Shadow`, `AppTheme.styleNavigationBar()` for consistency
- `AGENTS.md` is gitignored (not version controlled)
