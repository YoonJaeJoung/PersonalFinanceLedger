import SwiftUI
import SwiftData

@main
struct PersonalFinanceLedgerApp: App {
    
    /// A statically initialized shared ModelContainer.
    /// This ensures that the initialization logic (including restore, backup, and
    /// store creation) is executed EXACTLY ONCE over the lifetime of the application.
    /// This avoids concurrent file access or race conditions that could throw
    /// `SQLITE_MISUSE` or "The file couldn't be opened" if the App struct is re-evaluated.
    static var sharedContainer: ModelContainer = {
        // Phase 1: Restore database from backup if store file is missing
        let didRestore = BackupManager.shared.restoreIfNeeded()

        // Phase 2: Back up existing database (skip if we just restored)
        if !didRestore {
            BackupManager.shared.backupDatabase()
        }

        // Phase 3: Create model container with migration plan
        do {
            return try ModelContainer(
                for: Transaction.self, CategoryItem.self, AccountItem.self,
                migrationPlan: LedgerMigrationPlan.self
            )
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            print("⚠️ Attempting recovery: backing up corrupt store and creating fresh container…")

            // Emergency backup before wiping
            BackupManager.shared.backupDatabase()

            // Remove the corrupt/incompatible store files so SwiftData can start fresh
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for file in ["default.store", "default.store-wal", "default.store-shm"] {
                    let url = appSupport.appendingPathComponent(file)
                    try? FileManager.default.removeItem(at: url)
                }
            }

            // Retry — this should succeed on an empty store
            do {
                let freshContainer = try ModelContainer(
                    for: Transaction.self, CategoryItem.self, AccountItem.self,
                    migrationPlan: LedgerMigrationPlan.self
                )
                print("✅ Fresh container created. Data is available in Backups/ for manual restore.")
                return freshContainer
            } catch {
                fatalError("Failed to create ModelContainer even after reset: \(error)")
            }
        }
    }()

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
            .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(Self.sharedContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 700)
        .commands {
            AppMenuCommands()
        }
        .environment(\.showAddCategoryBinding, $showAddCategory)
        .environment(\.showEditCategoriesBinding, $showEditCategories)
        .environment(\.showAddAccountBinding, $showAddAccount)
        .environment(\.showEditAccountsBinding, $showEditAccounts)
    }
}
