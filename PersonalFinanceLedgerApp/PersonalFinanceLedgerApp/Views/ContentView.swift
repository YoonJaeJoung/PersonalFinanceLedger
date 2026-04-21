import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(LedgerStore.self) private var store
    @State private var viewModel = LedgerViewModel()
    @State private var hasSeeded = false

    @Binding var showAddCategory: Bool
    @Binding var showEditCategories: Bool
    @Binding var showAddAccount: Bool
    @Binding var showEditAccounts: Bool

    #if os(iOS)
    @State private var showCSVImporter = false
    @State private var showCSVExporter = false
    @State private var showCategoryExporter = false
    @State private var showCategoryImporter = false
    #endif

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
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
        #if os(iOS)
        .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                performCSVImport(from: url)
            }
        }
        .fileImporter(isPresented: $showCategoryImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                performCategoriesImport(from: url)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import CSV Files…") { showCSVImporter = true }
                    Button("Import Categories…") { showCategoryImporter = true }
                    Divider()
                    Button("Add Category…") { showAddCategory = true }
                    Button("Edit Categories…") { showEditCategories = true }
                    Divider()
                    Button("Add Account…") { showAddAccount = true }
                    Button("Edit Accounts…") { showEditAccounts = true }
                    Divider()
                    Button("Clear Data & Restore Defaults", role: .destructive) { clearDataAndRestoreDefaults() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        #endif
        .onAppear {
            if !hasSeeded {
                store.seedDefaultsIfNeeded()
                store.cleanupDuplicateCategories()
                hasSeeded = true
            }
        }
        .onChange(of: store.accounts.map { "\($0.name)-\($0.sortOrder)" }, initial: true) { _, _ in
            viewModel.syncAccounts(store.sortedAccounts.map(\.name))
        }
        .onChange(of: store.categories.map { "\($0.name)-\($0.type)-\($0.sortOrder)-\($0.colorHex)" }, initial: true) { _, _ in
            viewModel.syncCategories(store.sortedCategories)
        }
        #if os(macOS)
        .focusedSceneValue(\.importExportActions, ImportExportActions(
            importCSV: { importCSVFiles() },
            exportCSV: { exportCSVFiles() },
            exportCategories: { exportCategoriesCSV() },
            importCategories: { importCategoriesCSV() }
        ))
        .focusedSceneValue(\.maintenanceActions, MaintenanceActions(
            clearAndRestoreDefaults: { clearDataAndRestoreDefaults() }
        ))
        #endif
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
                ForEach(store.sortedAccounts) { acct in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedAccounts.contains(acct.name) },
                        set: { isOn in
                            if isOn { viewModel.selectedAccounts.insert(acct.name) }
                            else { viewModel.selectedAccounts.remove(acct.name) }
                        }
                    )) {
                        Text(acct.name)
                    }
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
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
                allTransactions: store.sortedTransactions,
                categoryItems: store.sortedCategories,
                accountItems: store.sortedAccounts
            )
        case .summary:
            SummaryView(
                transactions: viewModel.filteredTransactions(from: store.sortedTransactions),
                allTransactions: store.sortedTransactions,
                categoryItems: store.sortedCategories,
                accountItems: store.sortedAccounts,
                viewModel: viewModel
            )
        }
    }

    // MARK: - CSV Import

    #if os(macOS)
    private func importCSVFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select the data folder containing CSV files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            performCSVImport(from: url)
        }
    }
    #endif

    private func performCSVImport(from url: URL) {
        do {
            let count = try CSVImporter.importAllCSVs(from: url, accountItems: store.sortedAccounts, store: store)
            viewModel.importMessage = "Successfully imported \(count) transactions."
        } catch {
            viewModel.importMessage = "Import error: \(error.localizedDescription)"
        }
        viewModel.showingImportAlert = true
    }

    // MARK: - CSV Export

    #if os(macOS)
    private func exportCSVFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select export destination folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            performCSVExport(to: url)
        }
    }
    #endif

    private func performCSVExport(to url: URL) {
        var exported = 0
        for acct in store.sortedAccounts where !acct.csvFileName.isEmpty {
            let csv = CSVImporter.exportCSV(transactions: store.sortedTransactions, account: acct.name)
            let fileURL = url.appendingPathComponent(acct.csvFileName)
            try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
            exported += 1
        }
        viewModel.importMessage = "Exported \(exported) CSV files."
        viewModel.showingImportAlert = true
    }

    // MARK: - Categories CSV Export

    #if os(macOS)
    private func exportCategoriesCSV() {
        let panel = NSOpenPanel()
        panel.title = "Select export destination folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            performCategoriesExport(to: url)
        }
    }
    #endif

    private func performCategoriesExport(to url: URL) {
        var csv = "Name,Type,Sort Order,ColorHex\n"
        for item in store.sortedCategories {
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

    // MARK: - Categories CSV Import

    #if os(macOS)
    private func importCategoriesCSV() {
        let panel = NSOpenPanel()
        panel.title = "Select categories CSV file"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            performCategoriesImport(from: url)
        }
    }
    #endif

    private func performCategoriesImport(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            if lines.count > 1 {
                var imported: [(name: String, type: String, colorHex: String, sortOrder: Int)] = []
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
                        imported.append((name: name, type: type, colorHex: colorHex, sortOrder: sortOrder))
                    }
                }
                store.importCategories(imported)
                viewModel.importMessage = "Successfully imported \(imported.count) categories."
            } else {
                viewModel.importMessage = "CSV file is empty."
            }
        } catch {
            viewModel.importMessage = "Import error: \(error.localizedDescription)"
        }
        viewModel.showingImportAlert = true
    }

    // MARK: - Maintenance: Clear data and restore defaults
    private func clearDataAndRestoreDefaults() {
        store.clearAllAndRestoreDefaults()
    }
}

#Preview {
    ContentView(
        showAddCategory: .constant(false),
        showEditCategories: .constant(false),
        showAddAccount: .constant(false),
        showEditAccounts: .constant(false)
    )
    .environment(LedgerStore())
}
