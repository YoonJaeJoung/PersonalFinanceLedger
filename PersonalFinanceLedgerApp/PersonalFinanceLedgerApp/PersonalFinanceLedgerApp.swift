import SwiftUI

@main
struct PersonalFinanceLedgerApp: App {

    @State private var store = LedgerStore()

    @State private var showAddCategory = false
    @State private var showEditCategories = false
    @State private var showAddAccount = false
    @State private var showEditAccounts = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                showAddCategory: $showAddCategory,
                showEditCategories: $showEditCategories,
                showAddAccount: $showAddAccount,
                showEditAccounts: $showEditAccounts
            )
            #if os(macOS)
            .frame(minWidth: 900, minHeight: 600)
            #endif
            .environment(store)
            .onAppear {
                // One-time migration from SwiftData to JSON
                SwiftDataMigrator.migrateIfNeeded(to: store)
            }
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 700)
        .commands {
            AppMenuCommands()
        }
        .environment(\.showAddCategoryBinding, $showAddCategory)
        .environment(\.showEditCategoriesBinding, $showEditCategories)
        .environment(\.showAddAccountBinding, $showAddAccount)
        .environment(\.showEditAccountsBinding, $showEditAccounts)
        #endif
    }
}
