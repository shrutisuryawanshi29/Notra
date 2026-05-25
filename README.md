# Notra

Notion-powered personal finance tracker for iOS. UIKit + programmatic UI (no storyboards), MVVM.

## Features

- **Notion Integration** — authenticate via Integration Token, select workspace page
- **Database Discovery** — automatic discovery of accessible databases
- **Role Assignment** — label databases as Expense / Income / Ignore
- **Column Mapping** — map Notion columns to Title / Amount / Category / Date
- **Dashboard** — monthly summary with expense/income totals, per-category breakdowns, and budget utilization tracking with circular progress indicators
- **Expense / Income Lists** — grouped by date, filterable by Notion column values and date range
- **Filter System** — dynamic property types (title, rich_text, number, date, select, multi_select, relation, checkbox, status), AND logic, filtered total summary bar
- **Add Transactions** — insert new expenses/incomes via Notion API; month classification auto-defaults from transaction date
- **Deep Links** — `notra://add-expense` and `notra://add-income` with optional `title`, `amount`, `date` (yyyy-MM-dd), `notes` params
- **Category Parsing** — from select, multi-select, relation properties, and text/title
- **Monthly Budget Tracking** — auto-detects budget columns in related category databases, shows per-category utilization with circular rings, two-column card grid layout

## Requirements

- iOS 26.0+
- Xcode 15.4+
- Notion Integration Token

## Getting Started

1. **Create a Notion Integration**
   - Go to [Notion My Integrations](https://www.notion.so/my-integrations)
   - Create a new integration
   - Copy the "Internal Integration Token"

2. **Share Your Database**
   - Open your Notion finance database
   - Click the `...` menu (top right)
   - Select "Connect to" → your integration

3. **Build & Run**
   ```bash
   xcodebuild -project Notra.xcodeproj -scheme Notra -configuration Debug \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
   ```

## Project Structure

```
Notra/
├── Controllers/       # ViewControllers
├── ViewModels/        # Business logic
├── Models/            # Data models
├── Services/          # API & storage (NotionService, SessionCacheManager, etc.)
├── Helpers/           # AppConstants + AppTheme (warm cream/brown palette)
└── Extensions/        # Extensions (empty)
```

## Debug

```swift
print(ColumnMappingService.shared.getSessionSummary())
print(SessionCacheManager.shared.getTransactionSummary())
```

Log prefixes: `[SetupState]`, `[SessionCache]`, `[DataFetcher]`, `[NotionService]`, `[DashboardViewModel]`, `[Analytics]`, `[AddTransactionVM]`, `[AddTransactionVC]`, `[TransactionInsert]`, `[DeepLink]`, `[ExpenseFilter]`, `[IncomeFilter]`

## Filters

Expense and Income lists support column-based filtering. Open the filter panel via the nav bar button to:
- Set a **date range** (From / To) — auto-dismisses on selection, clearable with × button
- Add **column filter rows** — pick a property → condition → value
- Supports all Notion property types (except read-only/computed types)
- Relation properties load lazily from the target database
- Summary bar at the bottom shows the filtered total

## License

MIT
