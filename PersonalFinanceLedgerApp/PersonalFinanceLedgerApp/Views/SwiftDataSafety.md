//
//  PersonalFinanceLedgerApp.swift
//  PersonalFinanceLedger
//
//  Created by Developer on 2023-06-01.
//

import SwiftUI
import SwiftData

@main
struct PersonalFinanceLedgerApp: App {
    static let sharedContainer: ModelContainer = {
        do {
            try BackupManager.shared.restoreIfMissing()
            try BackupManager.shared.backupDatabaseIfNeeded()

            let config = ModelConfiguration(
                schemaVersion: 2,
                migrationPlan: LedgerMigrationPlan()
            )

            return try ModelContainer(
                for: [Transaction.self, CategoryItem.self, AccountItem.self],
                configurations: [config]
            )
        } catch {
            // Log error
            print("Failed to initialize ModelContainer: \(error.localizedDescription)")
            // Backup and delete corrupted store files for forensics
            do {
                try BackupManager.shared.backupDatabaseForensics()
                try BackupManager.shared.removeStoreFiles()
                // Attempt fresh container creation without migration
                let config = ModelConfiguration(
                    schemaVersion: 2,
                    migrationPlan: LedgerMigrationPlan()
                )
                return try ModelContainer(
                    for: [Transaction.self, CategoryItem.self, AccountItem.self],
                    configurations: [config]
                )
            } catch {
                fatalError("Unable to recover store: \(error.localizedDescription)")
            }
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedContainer)
                .onAppear {
                    do {
                        try CategoryInfo.seedDefaultsIfNeeded(context: sharedContainer.mainContext)
                    } catch {
                        print("Failed to seed default categories/accounts: \(error.localizedDescription)")
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                do {
                    try sharedContainer.mainContext.save()
                } catch {
                    print("Failed to save context on scene phase change: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Migration Plan

struct LedgerMigrationPlan: MigrationPlan {
    var fromSchemaVersion: Int = 1
    var toSchemaVersion: Int = 2

    func migrate(storeURL: URL, from oldVersion: Int, to newVersion: Int) throws {
        // Lightweight migration; no manual steps needed here
    }
}

// MARK: - Backup Manager

final class BackupManager {
    static let shared = BackupManager()

    private let fileManager = FileManager.default
    private var storeURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("default.store")
    }
    private var backupsDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups")
    }

    private init() {
        try? fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }

    func restoreIfMissing() throws {
        if !fileManager.fileExists(atPath: storeURL.path) {
            let backups = try fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            let sortedBackups = backups.sorted { lhs, rhs in
                (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast >
                (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            }
            if let latestBackup = sortedBackups.first {
                try fileManager.copyItem(at: latestBackup, to: storeURL)
                print("Restored store from backup: \(latestBackup.lastPathComponent)")
            }
        }
    }

    func backupDatabaseIfNeeded() throws {
        // Skip if just restored to avoid duplicate backup immediately after restore
        if fileManager.fileExists(atPath: storeURL.path) {
            try backupDatabase()
        }
    }

    func backupDatabase() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = backupsDirectory.appendingPathComponent("default-\(timestamp).store")
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.copyItem(at: storeURL, to: backupURL)
            print("Backup created at: \(backupURL.path)")
        }
    }

    func backupDatabaseForensics() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let forensicBackupURL = backupsDirectory.appendingPathComponent("forensics-\(timestamp).store")
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.copyItem(at: storeURL, to: forensicBackupURL)
            print("Forensic backup created at: \(forensicBackupURL.path)")
        }
    }

    func removeStoreFiles() throws {
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
            print("Deleted corrupt store file at: \(storeURL.path)")
        }
    }
}

// MARK: - CategoryInfo Seed Defaults

enum CategoryInfo {
    static func seedDefaultsIfNeeded(context: ModelContext) throws {
        let fetchRequest = FetchDescriptor<CategoryItem>()
        let count = try context.count(for: fetchRequest)
        if count == 0 {
            let defaultCategories = [
                CategoryItem(name: "Groceries"),
                CategoryItem(name: "Utilities"),
                CategoryItem(name: "Entertainment"),
                CategoryItem(name: "Transportation"),
                CategoryItem(name: "Income")
            ]
            defaultCategories.forEach { context.insert($0) }

            let defaultAccounts = [
                AccountItem(name: "Checking Account"),
                AccountItem(name: "Savings Account"),
                AccountItem(name: "Credit Card")
            ]
            defaultAccounts.forEach { context.insert($0) }

            do {
                try context.save()
            } catch {
                print("Error saving default categories/accounts: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
