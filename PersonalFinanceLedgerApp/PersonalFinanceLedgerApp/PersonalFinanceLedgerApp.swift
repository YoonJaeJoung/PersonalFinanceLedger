import SwiftUI

@main
struct PersonalFinanceLedgerApp: App {

    @State private var store = LedgerStore()

    #if os(macOS)
    @State private var showAddCategory = false
    @State private var showEditCategories = false
    @State private var showAddAccount = false
    @State private var showEditAccounts = false
    #endif

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            iOSRootView()
                .environment(store)
                .onAppear {
                    SwiftDataMigrator.migrateIfNeeded(to: store)
                }
            #else
            ContentView(
                showAddCategory: $showAddCategory,
                showEditCategories: $showEditCategories,
                showAddAccount: $showAddAccount,
                showEditAccounts: $showEditAccounts
            )
            .frame(minWidth: 900, minHeight: 600)
            .environment(store)
            .onAppear {
                SwiftDataMigrator.migrateIfNeeded(to: store)
            }
            #endif
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
