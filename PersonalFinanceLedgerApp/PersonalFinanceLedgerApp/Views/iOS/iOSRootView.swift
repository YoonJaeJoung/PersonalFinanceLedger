#if os(iOS)
import SwiftUI

struct iOSRootView: View {
    @Environment(LedgerStore.self) private var store
    @State private var viewModel = LedgerViewModel()
    @State private var hasSeeded = false

    var body: some View {
        TabView {
            iOSDataTab(viewModel: viewModel)
                .tabItem {
                    Label("Data", systemImage: "list.bullet.rectangle")
                }

            iOSSummaryTab(viewModel: viewModel)
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }
        }
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
    }
}

// MARK: - Summary Tab Wrapper

struct iOSSummaryTab: View {
    @Environment(LedgerStore.self) private var store
    @Bindable var viewModel: LedgerViewModel

    var body: some View {
        NavigationStack {
            SummaryView(
                transactions: viewModel.filteredTransactions(from: store.sortedTransactions),
                allTransactions: store.sortedTransactions,
                categoryItems: store.sortedCategories,
                accountItems: store.sortedAccounts,
                viewModel: viewModel
            )
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#endif
