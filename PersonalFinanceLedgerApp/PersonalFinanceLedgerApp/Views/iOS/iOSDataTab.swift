#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct iOSDataTab: View {
    @Environment(LedgerStore.self) private var store
    @Bindable var viewModel: LedgerViewModel

    @State private var isAddingEntry = false
    @State private var showAccountsSheet = false
    @State private var showAddCategory = false
    @State private var showEditCategories = false
    @State private var showAddAccount = false
    @State private var showEditAccounts = false
    @State private var showCSVImporter = false
    @State private var showCategoryImporter = false
    @State private var navigationPath = NavigationPath()

    private var filtered: [Transaction] {
        viewModel.filteredTransactions(from: store.sortedTransactions)
    }

    private var balance: Double {
        viewModel.balance(of: filtered)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Collapsible filter panel
                    if viewModel.isFilterPanelOpen {
                        iOSFilterPanel(viewModel: viewModel, categoryItems: store.sortedCategories)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Divider()
                    }

                    // Transaction list
                    if filtered.isEmpty {
                        Spacer()
                        Text(viewModel.selectedAccounts.isEmpty
                             ? "Select at least one account"
                             : "No matching records")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        Spacer()
                    } else {
                        List {
                            ForEach(filtered) { transaction in
                                iOSTransactionRow(
                                    transaction: transaction,
                                    categoryItems: store.sortedCategories
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigationPath.append(transaction)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deleteTransaction(id: transaction.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }

                    // Balance bar
                    Divider()
                    HStack {
                        Text("Balance")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "$%.2f", abs(balance)))
                            .fontWeight(.semibold)
                            .foregroundStyle(balance >= 0 ? .green : .red)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.06))
                }

                // Floating add button
                if !isAddingEntry {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isAddingEntry = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isAddingEntry {
                    iOSInputBar(
                        viewModel: viewModel,
                        categoryItems: store.sortedCategories,
                        isPresented: $isAddingEntry
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isFilterPanelOpen.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .tint(viewModel.isFilterPanelOpen ? .accentColor : nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAccountsSheet = true
                    } label: {
                        Image(systemName: "building.columns")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Category…") { showAddCategory = true }
                        Button("Edit Categories…") { showEditCategories = true }
                        Divider()
                        Button("Add Account…") { showAddAccount = true }
                        Button("Edit Accounts…") { showEditAccounts = true }
                        Divider()
                        Button("Import CSV Files…") { showCSVImporter = true }
                        Button("Import Categories…") { showCategoryImporter = true }
                        Divider()
                        Button("Clear Data & Restore Defaults", role: .destructive) {
                            store.clearAllAndRestoreDefaults()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(for: Transaction.self) { transaction in
                iOSEditTransactionView(
                    transaction: transaction,
                    categoryItems: store.sortedCategories,
                    viewModel: viewModel
                )
            }
        }
        .toolbar(isAddingEntry ? .hidden : .automatic, for: .tabBar)
        .sheet(isPresented: $showAccountsSheet) {
            iOSAccountsSheet(viewModel: viewModel)
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
        .alert("CSV Import", isPresented: $viewModel.showingImportAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.importMessage)
        }
    }

    // MARK: - CSV Import

    private func performCSVImport(from url: URL) {
        do {
            let count = try CSVImporter.importAllCSVs(
                from: url,
                accountItems: store.sortedAccounts,
                store: store
            )
            viewModel.importMessage = "Successfully imported \(count) transactions."
        } catch {
            viewModel.importMessage = "Import error: \(error.localizedDescription)"
        }
        viewModel.showingImportAlert = true
    }

    // MARK: - Categories Import

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
}

// MARK: - Transaction Row

struct iOSTransactionRow: View {
    let transaction: Transaction
    let categoryItems: [CategoryItem]

    var body: some View {
        HStack(spacing: 12) {
            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            CategoryBadge(category: transaction.category, categoryItems: categoryItems)

            Text(transaction.descriptionText)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Text(transaction.displayAmount)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(transaction.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Accounts Sheet

struct iOSAccountsSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LedgerViewModel

    var body: some View {
        NavigationStack {
            List {
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
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#endif
