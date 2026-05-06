# Notra

A Notion-powered personal finance tracker for iOS. Notra adapts to your existing Notion workspace structure without requiring you to restructure your databases.

## Features

### Phase 1: Setup
- Notion Integration token authentication
- Page selection from workspace

### Phase 2: Database Discovery & Mapping
- Automatic discovery of accessible databases
- Role assignment (Expense/Income/Ignore)
- Column mapping (Title/Amount/Category/Date)
- Category parsing (select, multi-select, relation, text)
- Session caching for fast access

## Requirements

- iOS 15.0+
- Xcode 15.0+
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
   - Open `Notra.xcodeproj` in Xcode
   - Select a simulator
   - Press Cmd+R to build and run

## How It Works

### Token Entry
Enter your Notion Integration token to authenticate.

### Page Selection
Select the Notion page containing your finance databases.

### Database Discovery
Notra discovers all accessible databases in your workspace.

### Role Assignment
Assign each database as:
- **Expense** - for expense tracking
- **Income** - for income tracking
- **Ignore** - skip this database

### Column Mapping
Map your Notion columns to internal fields:
- Title
- Amount
- Category
- Date

### Category Parsing
Automatically detects categories from:
- Select properties
- Multi-select properties
- Relation properties
- Text/Title properties

## Project Structure

```
Notra/
├── Controllers/       # ViewControllers
├── ViewModels/        # Business logic
├── Models/            # Data models
├── Services/         # API & Storage
├── Helpers/           # Constants
└── Extensions/        # Extensions
```

## Debug

Print session summary:
```swift
print(ColumnMappingService.shared.getSessionSummary())
```

## Future Phases

- Dashboard summaries
- Expense tracking
- Income tracking
- Analytics & charts
- Category-wise spending analysis

## License

MIT
