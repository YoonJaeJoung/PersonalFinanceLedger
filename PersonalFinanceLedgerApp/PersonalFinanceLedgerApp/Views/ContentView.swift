import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]
    @State private var viewModel = LedgerViewModel()

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
                ForEach(CategoryInfo.accounts, id: \.self) { account in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedAccounts.contains(account) },
                        set: { isOn in
                            if isOn { viewModel.selectedAccounts.insert(account) }
                            else { viewModel.selectedAccounts.remove(account) }
                        }
                    )) {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(account)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Section {
                Button {
                    importCSVFiles()
                } label: {
                    Label("Import CSV Files...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    exportCSVFiles()
                } label: {
                    Label("Export CSV Files...", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } header: {
                Text("Data")
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selectedTab {
        case .data:
            TransactionListView(viewModel: viewModel, allTransactions: allTransactions)
        case .summary:
            VStack {
                Image(systemName: "chart.bar.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Summary coming soon")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            do {
                let count = try CSVImporter.importAllCSVs(from: url, context: modelContext)
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
            for (account, filename) in CategoryInfo.accountFileMapping {
                let csv = CSVImporter.exportCSV(transactions: allTransactions, account: account)
                let fileURL = url.appendingPathComponent(filename)
                try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
                exported += 1
            }
            viewModel.importMessage = "Exported \(exported) CSV files."
            viewModel.showingImportAlert = true
        }
    }
}
