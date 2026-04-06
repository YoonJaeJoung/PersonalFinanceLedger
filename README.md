# PersonalFinanceLedger
This is a project to make an on-device decent finance ledger to track personal expenses

The [app](./app/) is the html webapp using the data in [data](./data/). 

I then migrated the web app into macOS app. The [xcode Project](./PersonalFinanceLedgerApp/) is the macOS app. 

Finally, [csvConvert](./csvConvert/) is a python script to convert transaction csv files downloaded from the bank into the format used in this project.

## Data Safety

The macOS app includes several layers of protection against data loss:

- **Schema Versioning** (`SchemaVersioning.swift`): Uses SwiftData's `VersionedSchema` and `SchemaMigrationPlan` to ensure model changes trigger proper migration instead of silently wiping the database. When adding new model fields, create a new schema version (e.g., `SchemaV2`) and a corresponding migration stage.
- **Auto-Backup**: On every launch, the app backs up `default.store` (and WAL/SHM files) to `~/Library/Application Support/Backups/`, keeping the last 6 sets.
- **Auto-Restore**: If the store file is missing on launch but backups exist, the app automatically restores from the latest backup before SwiftData initializes.

## Category CSV Format

The category export/import CSV uses 4 columns:

```
Name,Type,Sort Order,ColorHex
Groceries,expense,0,#EF4444
```

Importing a CSV with only 3 columns (no `ColorHex`) is supported — missing colors default to `#9CA3AF` (gray).

## Summary Tab

The macOS app includes a **Summary** tab (accessible from the sidebar) that visualizes expense data with interactive SwiftUI Charts:

- **Total** — Vertical bar chart colored by each category's assigned color, with a text breakdown showing exact amounts and percentages.
- **Month** — Stacked vertical bar chart showing monthly spending broken down by category. Click any bar to see its category detail below.
- **Week** — Stacked bar chart of weekly spending (last 26 weeks if data is large) with a dashed average line. Click bars for category breakdown.
- **Day** — Stacked bar chart across Mon–Sun with average/day stat. Click bars for category breakdown.

The Summary tab respects the same account and filter selections as the Data tab.

### Refund Matching

When an income transaction has category "Refund" and its absolute amount matches an expense transaction, and at least one word in the refund description appears in the expense description (case-insensitive), the expense is excluded from all summaries. Excluded transactions are listed in a collapsible section at the bottom for user review.

### PDF Export

The **Export PDF** button generates a bi-weekly (first/second half of each month) finance report:

- **Title**: static let pdfTitle (shared across all pages)
- **Per biweekly period**: A page with the date range, a vertical bar chart (top 30%) showing category totals for expenses and income, and all transactions in date order (bottom 70%). Overflow transactions continue on the next page without a chart.
- **Last page**: Total summary with entire-date-span bar charts and current balance of each account.
- **Footer**: Page number on every page.

