import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]
    @Query(sort: \CategoryItem.sortOrder) private var categoryItems: [CategoryItem]
    @Query(sort: \AccountItem.sortOrder) private var accountItems: [AccountItem]
    @State private var viewModel = LedgerViewModel()
    @State private var hasSeeded = false

    @Binding var showAddCategory: Bool
    @Binding var showEditCategories: Bool
    @Binding var showAddAccount: Bool
    @Binding var showEditAccounts: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .alert("CSV Import", isPresented: $viewModel.showingImportAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.importMessage)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet()
        }
        .sheet(isPresented: $showEditCategories) {
            EditCategorySheet()
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
        }
        .sheet(isPresented: $showEditAccounts) {
            EditAccountSheet()
        }
        .onAppear {
            if !hasSeeded {
                CategoryInfo.seedDefaultsIfNeeded(context: modelContext)
                cleanupDuplicateCategories()
                hasSeeded = true
            }
        }
        .onChange(of: accountItems.map { "\($0.name)-\($0.sortOrder)" }, initial: true) { _, _ in
            viewModel.syncAccounts(accountItems.map(\.name))
        }
        .onChange(of: categoryItems.map { "\($0.name)-\($0.type)-\($0.sortOrder)-\($0.colorHex)" }, initial: true) { _, _ in
            viewModel.syncCategories(categoryItems)
        }
        .focusedSceneValue(\.importExportActions, ImportExportActions(
            importCSV: { importCSVFiles() },
            exportCSV: { exportCSVFiles() },
            exportCategories: { exportCategoriesCSV() },
            importCategories: { importCategoriesCSV() }
        ))
        .focusedSceneValue(\.maintenanceActions, MaintenanceActions(
            clearAndRestoreDefaults: { clearDataAndRestoreDefaults() }
        ))
    }

    private func cleanupDuplicateCategories() {
        var seen = Set<String>()
        for item in categoryItems {
            let key = "\(item.name)-\(item.type)"
            if seen.contains(key) {
                modelContext.delete(item)
            } else {
                seen.insert(key)
            }
        }
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save after cleaning duplicate categories: \(error)")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section("Navigation") {
                ForEach(LedgerViewModel.Tab.allCases, id: \.self) { tab in
                    HStack {
                        Image(systemName: tab == .data ? "list.bullet.rectangle" : "chart.bar.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(tab.rawValue)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedTab = tab }
                    .listRowBackground(
                        viewModel.selectedTab == tab
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                    )
                }
            }

            Section("Accounts") {
                ForEach(accountItems) { acct in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedAccounts.contains(acct.name) },
                        set: { isOn in
                            if isOn { viewModel.selectedAccounts.insert(acct.name) }
                            else { viewModel.selectedAccounts.remove(acct.name) }
                        }
                    )) {
                        Text(acct.name)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selectedTab {
        case .data:
            TransactionListView(
                viewModel: viewModel,
                allTransactions: allTransactions,
                categoryItems: categoryItems,
                accountItems: accountItems
            )
        case .summary:
            SummaryView(
                transactions: viewModel.filteredTransactions(from: allTransactions),
                allTransactions: allTransactions,
                categoryItems: categoryItems,
                accountItems: accountItems,
                viewModel: viewModel
            )
        }
    }

    // MARK: - CSV Import

    private func importCSVFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select the data folder containing CSV files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // Safety: backup current database before bulk import
            BackupManager.shared.backupDatabase()

            do {
                let count = try CSVImporter.importAllCSVs(from: url, accountItems: accountItems, context: modelContext)
                viewModel.importMessage = "Successfully imported \(count) transactions."
            } catch {
                viewModel.importMessage = "Import error: \(error.localizedDescription)"
            }
            viewModel.showingImportAlert = true
        }
    }

    // MARK: - CSV Export

    private func exportCSVFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select export destination folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            var exported = 0
            for acct in accountItems where !acct.csvFileName.isEmpty {
                let csv = CSVImporter.exportCSV(transactions: allTransactions, account: acct.name)
                let fileURL = url.appendingPathComponent(acct.csvFileName)
                try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
                exported += 1
            }
            viewModel.importMessage = "Exported \(exported) CSV files."
            viewModel.showingImportAlert = true
        }
    }

    // MARK: - Categories CSV Export

    private func exportCategoriesCSV() {
        let panel = NSOpenPanel()
        panel.title = "Select export destination folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // Build CSV header
            var csv = "Name,Type,Sort Order,ColorHex\n"
            for item in categoryItems {
                let name = item.name.replacingOccurrences(of: ",", with: " ")
                let type = item.type
                let sort = String(item.sortOrder)
                let color = item.colorHex
                csv.append("\(name),\(type),\(sort),\(color)\n")
            }
            let fileURL = url.appendingPathComponent("categories.csv")
            do {
                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
                viewModel.importMessage = "Exported categories.csv."
            } catch {
                viewModel.importMessage = "Export error: \(error.localizedDescription)"
            }
            viewModel.showingImportAlert = true
        }
    }

    // MARK: - Categories CSV Import

    private func importCategoriesCSV() {
        let panel = NSOpenPanel()
        panel.title = "Select categories CSV file"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                if lines.count > 1 {
                    var count = 0
                    for line in lines.dropFirst() {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        let fields = trimmed.components(separatedBy: ",")
                        if fields.count >= 3 {
                            let name = fields[0].trimmingCharacters(in: .whitespaces)
                            let type = fields[1].trimmingCharacters(in: .whitespaces)
                            let sortOrderStr = fields[2].trimmingCharacters(in: .whitespaces)
                            let colorHex = fields.count >= 4
                                ? fields[3].trimmingCharacters(in: .whitespaces)
                                : "#9CA3AF"
                            
                            let sortOrder = Int(sortOrderStr) ?? 0
                            
                            if let existing = categoryItems.first(where: { $0.name == name && $0.type == type }) {
                                existing.sortOrder = sortOrder
                                existing.colorHex = colorHex
                            } else {
                                let newCat = CategoryItem(name: name, type: type, colorHex: colorHex, sortOrder: sortOrder)
                                modelContext.insert(newCat)
                            }
                            count += 1
                        }
                    }
                    do {
                        try modelContext.save()
                    } catch {
                        print("⚠️ Failed to save categories after import: \(error)")
                        viewModel.importMessage = "Import error: \(error.localizedDescription)"
                    }
                    viewModel.importMessage = "Successfully imported \(count) categories."
                } else {
                    viewModel.importMessage = "CSV file is empty."
                }
            } catch {
                viewModel.importMessage = "Import error: \(error.localizedDescription)"
            }
            viewModel.showingImportAlert = true
        }
    }

    // MARK: - Maintenance: Clear data and restore defaults
    private func clearDataAndRestoreDefaults() {
        // Backup before destructive operation
        BackupManager.shared.backupDatabase()
        do {
            // Delete all existing data
            let txs = try modelContext.fetch(FetchDescriptor<Transaction>())
            for t in txs { modelContext.delete(t) }

            let cats = try modelContext.fetch(FetchDescriptor<CategoryItem>())
            for c in cats { modelContext.delete(c) }

            let accts = try modelContext.fetch(FetchDescriptor<AccountItem>())
            for a in accts { modelContext.delete(a) }

            try modelContext.save()

            // Reseed defaults
            CategoryInfo.seedDefaultsIfNeeded(context: modelContext)
        } catch {
            print("⚠️ Failed to clear and restore defaults: \(error)")
        }
    }
}

#Preview {
    ContentView(
        showAddCategory: .constant(false),
        showEditCategories: .constant(false),
        showAddAccount: .constant(false),
        showEditAccounts: .constant(false)
    )
    .modelContainer(for: [Transaction.self, CategoryItem.self, AccountItem.self], inMemory: true)
}

