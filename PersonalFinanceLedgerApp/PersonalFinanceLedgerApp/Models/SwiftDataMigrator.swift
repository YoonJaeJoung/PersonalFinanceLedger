import Foundation
import CoreData

/// One-time migrator that reads existing SwiftData (SQLite) store and writes JSON files.
/// Uses Core Data directly to read the old store, since the models have been converted from @Model to structs.
/// This file can be removed in a future release once all users have migrated.
struct SwiftDataMigrator {

    static func migrateIfNeeded(to store: LedgerStore) {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let storeFile = appSupport.appendingPathComponent("default.store")
        let migrationMarker = appSupport.appendingPathComponent(".json-migration-complete")

        // Skip if already migrated or no SwiftData store exists
        guard fm.fileExists(atPath: storeFile.path),
              !fm.fileExists(atPath: migrationMarker.path) else {
            return
        }

        // Also skip if JSON files already have data (migration was partially done)
        if !store.transactions.isEmpty || !store.categories.isEmpty {
            writeMigrationMarker(at: migrationMarker)
            return
        }

        print("🔄 Starting one-time SwiftData → JSON migration…")

        do {
            // Build Core Data model matching the SwiftData schema
            let model = buildManagedObjectModel()

            let container = NSPersistentContainer(name: "LegacyMigration", managedObjectModel: model)
            let storeDescription = NSPersistentStoreDescription(url: storeFile)
            storeDescription.isReadOnly = true
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [storeDescription]

            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
            }
            if let loadError {
                print("⚠️ Failed to open legacy SwiftData store: \(loadError)")
                writeMigrationMarker(at: migrationMarker)
                return
            }

            let context = container.viewContext

            // Fetch transactions
            let txRequest = NSFetchRequest<NSManagedObject>(entityName: "Transaction")
            let txObjects = (try? context.fetch(txRequest)) ?? []
            var migratedTransactions: [Transaction] = []
            for obj in txObjects {
                let t = Transaction(
                    id: UUID(),
                    date: obj.value(forKey: "date") as? Date ?? Date(),
                    descriptionText: obj.value(forKey: "descriptionText") as? String ?? "",
                    category: obj.value(forKey: "category") as? String ?? "",
                    amount: obj.value(forKey: "amount") as? Double ?? 0,
                    account: obj.value(forKey: "account") as? String ?? "Chase"
                )
                migratedTransactions.append(t)
            }

            // Fetch categories
            let catRequest = NSFetchRequest<NSManagedObject>(entityName: "CategoryItem")
            let catObjects = (try? context.fetch(catRequest)) ?? []
            var migratedCategories: [CategoryItem] = []
            for obj in catObjects {
                let c = CategoryItem(
                    id: UUID(),
                    name: obj.value(forKey: "name") as? String ?? "",
                    type: obj.value(forKey: "type") as? String ?? "expense",
                    colorHex: obj.value(forKey: "colorHex") as? String ?? "#9CA3AF",
                    sortOrder: (obj.value(forKey: "sortOrder") as? Int) ?? 0
                )
                migratedCategories.append(c)
            }

            // Fetch accounts
            let acctRequest = NSFetchRequest<NSManagedObject>(entityName: "AccountItem")
            let acctObjects = (try? context.fetch(acctRequest)) ?? []
            var migratedAccounts: [AccountItem] = []
            for obj in acctObjects {
                let a = AccountItem(
                    id: UUID(),
                    name: obj.value(forKey: "name") as? String ?? "",
                    csvFileName: obj.value(forKey: "csvFileName") as? String ?? "",
                    sortOrder: (obj.value(forKey: "sortOrder") as? Int) ?? 0
                )
                migratedAccounts.append(a)
            }

            // Write to LedgerStore
            if !migratedTransactions.isEmpty {
                store.addTransactions(migratedTransactions)
            }
            if !migratedCategories.isEmpty {
                for cat in migratedCategories {
                    store.addCategory(cat)
                }
            }
            if !migratedAccounts.isEmpty {
                for acct in migratedAccounts {
                    store.addAccount(acct)
                }
            }

            print("✅ Migration complete: \(migratedTransactions.count) transactions, \(migratedCategories.count) categories, \(migratedAccounts.count) accounts.")
            writeMigrationMarker(at: migrationMarker)

        } catch {
            print("⚠️ Migration failed: \(error)")
            writeMigrationMarker(at: migrationMarker)
        }
    }

    // MARK: - Core Data Model Definition

    /// Builds an NSManagedObjectModel that matches the SwiftData V2 schema.
    private static func buildManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Transaction entity
        let transactionEntity = NSEntityDescription()
        transactionEntity.name = "Transaction"
        transactionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        transactionEntity.properties = [
            makeAttribute("date", type: .dateAttributeType),
            makeAttribute("descriptionText", type: .stringAttributeType),
            makeAttribute("category", type: .stringAttributeType),
            makeAttribute("amount", type: .doubleAttributeType),
            makeAttribute("account", type: .stringAttributeType),
        ]

        // CategoryItem entity
        let categoryEntity = NSEntityDescription()
        categoryEntity.name = "CategoryItem"
        categoryEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        categoryEntity.properties = [
            makeAttribute("name", type: .stringAttributeType),
            makeAttribute("type", type: .stringAttributeType),
            makeAttribute("colorHex", type: .stringAttributeType),
            makeAttribute("sortOrder", type: .integer64AttributeType),
        ]

        // AccountItem entity
        let accountEntity = NSEntityDescription()
        accountEntity.name = "AccountItem"
        accountEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        accountEntity.properties = [
            makeAttribute("name", type: .stringAttributeType),
            makeAttribute("csvFileName", type: .stringAttributeType),
            makeAttribute("sortOrder", type: .integer64AttributeType),
        ]

        model.entities = [transactionEntity, categoryEntity, accountEntity]
        return model
    }

    private static func makeAttribute(_ name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = true
        return attr
    }

    private static func writeMigrationMarker(at url: URL) {
        try? "migrated".write(to: url, atomically: true, encoding: .utf8)
    }
}
