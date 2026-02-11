# Personal Finance Ledger — Web → Native macOS Migration

This document explains how each feature from the original web app (HTML/CSS/JS + Python) is now implemented in the native macOS SwiftUI application.

## Architecture Overview

| Layer | Web App | macOS App |
|---|---|---|
| **Data Storage** | CSV files (`data/*.csv`) via Python HTTP server | **SwiftData** (`@Model Transaction`) with automatic persistence |
| **Backend** | `main.py` — Python HTTP server with REST API | **None needed** — SwiftData manages CRUD directly |
| **Frontend** | `app/index.html` + `app/script/app.js` + `app/script/style.css` | **SwiftUI Views** — fully native macOS UI |
| **Styling** | Custom CSS (dark theme, glassmorphism) | **Native macOS appearance** — adapts to system dark/light mode |

## Feature Migration Map

### Data Layer

| Feature | Web Implementation | macOS Implementation |
|---|---|---|
| Data Model | CSV rows: `Date,Description,Category,Amount` | `Transaction.swift` — `@Model` class with `date`, `descriptionText`, `category`, `amount`, `account` properties |
| CRUD Operations | REST API calls (`fetch('/api/data/...')`) to Python server | SwiftData `ModelContext` — `insert()`, `delete()`, `save()` — automatic persistence |
| Data Loading | `loadAccount()` JS function → HTTP GET | `@Query` macro fetches all transactions automatically |
| CSV Compatibility | Direct CSV read/write | `CSVImporter.swift` — import existing CSVs via sidebar button + export back to CSV |

### UI Components

| Feature | Web (HTML/CSS) | macOS (SwiftUI) |
|---|---|---|
| **App Layout** | `.app-container` flex layout | `NavigationSplitView` with sidebar + detail |
| **Sidebar** | `<aside class="sidebar">` with tab buttons | Native `List` with `.sidebar` style, sections for Navigation, Accounts, Data |
| **Sidebar Tabs** | `<button class="tab-btn">` with `.active` class | `ForEach` over `Tab` enum with `onTapGesture`, highlighted row background |
| **Account Toggles** | `<input type="checkbox">` in account bar | Native `Toggle` with `.checkbox` style in sidebar |
| **Filter Toggle** | `<button id="filter-toggle-btn">` toggling `.hidden` | `Button` with `Label` and `systemImage: "line.3.horizontal.decrease"` |
| **Filter Panel** | `<div class="filter-panel">` with CSS transitions | Conditional `FilterPanelView` with `withAnimation` |
| **Description Filter** | `<input type="text">` | Native `TextField` with `.roundedBorder` style |
| **Amount Range** | Two `<input type="number">` | Two `TextField` inputs for min/max |
| **Date Range** | Two `<input type="date">` | Native `DatePicker` with `.date` components |
| **Category Chips** | `<label class="checkbox-label">` with CSS colors | `Button` toggles in `LazyVGrid`, colored with `CategoryInfo.color()` |
| **Data Table** | `<table>` with DOM-injected rows | SwiftUI `Table` with `TableColumn` definitions |
| **Column Headers** | `<th>` elements via JS | `TableColumn("Name")` declarations |
| **Amount Coloring** | `.amount-positive` / `.amount-negative` CSS classes | `.foregroundStyle(.green / .red)` modifier |
| **Category Badges** | `<span class="category-badge">` + inline JS colors | `CategoryBadge.swift` — `Text` with `.background` + `.overlay` rounded rect |
| **Account Badges** | `<span class="account-badge">` | `Text` with `.background(.quaternary)` and rounded clip |
| **Balance Row** | `<tfoot>` with computed balance | `HStack` with computed `balance` property |
| **Row Selection** | Checkbox column + JS event handlers | Native `Table` selection binding (`Set<PersistentIdentifier>`) |
| **Inline Editing** | DOM replacement with `<input>` elements | `EditTransactionSheet.swift` — native `Form` in a sheet |
| **Delete Rows** | JS → `fetch` POST `/delete_rows` | `modelContext.delete()` — direct SwiftData deletion |
| **Move Rows** | JS → `fetch` POST `/move_rows` | Direct property update: `transaction.account = newAccount` |
| **Input Bar** | `<div class="input-bar">` with form fields | `InputBarView.swift` — `HStack` with native pickers and text fields |
| **Expense/Income Toggle** | `<button id="toggle-type">` with CSS classes | `Button` with conditional red/green styling |
| **Category Autocomplete** | Custom JS dropdown (`.autocomplete-dropdown`) | Native `Picker` with `.menu` style, colored circle indicators |

### Styling

| Web Styling | macOS Equivalent |
|---|---|
| CSS custom properties (`--bg-color`, etc.) | System colors — automatic dark/light mode |
| `backdrop-filter: blur(12px)` | `.background(.bar)` — native vibrancy |
| `font-family: 'Inter'` | System font (San Francisco) |
| Custom scrollbar CSS | Native macOS scrollbars |
| Hover effects (`:hover`) | Native hover states on buttons/rows |
| `.hidden` class toggling | SwiftUI conditional rendering / `withAnimation` |

## How to Build & Run

1. **Open** `PersonalFinanceLedgerApp/PersonalFinanceLedgerApp.xcodeproj` in Xcode
2. **Press** ⌘R to build and run
3. **Import data**: Click "Import CSV Files..." in the sidebar → select the `data/` folder from the web app

## How to Import Existing CSV Data

The app includes a CSV importer that reads your existing `chase.csv`, `cash.csv`, `toss.csv`, and `travellog.csv` files:

1. In the sidebar, click **"Import CSV Files..."**
2. Select the `data/` directory from the original web app
3. All transactions are imported into SwiftData with the correct account names

## How to Export Back to CSV

1. In the sidebar, click **"Export CSV Files..."**
2. Select a destination folder
3. The app writes one CSV file per account in the original format
