
import Foundation
import SwiftData

struct BackupManager {
    static let shared = BackupManager()

    private let fileManager = FileManager.default
    private let backupDirectoryName = "Backups"

    // MARK: - Auto-Restore

    /// Attempt to restore database from the latest backup if the store file is missing.
    /// Call this BEFORE `.modelContainer` is initialized so SwiftData opens the restored store.
    /// Returns true if a restore was performed.
    @discardableResult
    func restoreIfNeeded() -> Bool {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return false }
        let storeURL = appSupportURL.appendingPathComponent("default.store")

        // Only restore if the store file doesn't exist
        guard !fileManager.fileExists(atPath: storeURL.path) else { return false }

        let backupDirURL = appSupportURL.appendingPathComponent(backupDirectoryName)
        guard fileManager.fileExists(atPath: backupDirURL.path) else { return false }

        // Find the latest backup timestamp
        guard let latestTimestamp = latestBackupTimestamp(in: backupDirURL) else {
            print("⚠️ No valid backup sets found for restore.")
            return false
        }

        print("🔄 Store file missing — attempting restore from backup (\(latestTimestamp))…")

        // Restore all related files (.store, .store-wal, .store-shm)
        let filesToRestore = ["default.store", "default.store-wal", "default.store-shm"]
        var restoredAny = false

        for filename in filesToRestore {
            let backupFilename = filename.replacingOccurrences(of: "default", with: "default-\(latestTimestamp)")
            let backupURL = backupDirURL.appendingPathComponent(backupFilename)
            let destURL = appSupportURL.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: backupURL.path) {
                do {
                    try fileManager.copyItem(at: backupURL, to: destURL)
                    print("✅ Restored \(filename) from backup")
                    restoredAny = true
                } catch {
                    print("⚠️ Failed to restore \(filename): \(error)")
                }
            }
        }

        if restoredAny {
            print("✅ Database restored from backup (\(latestTimestamp)).")
        }
        return restoredAny
    }

    // MARK: - Backup

    /// Perform a backup of the default.store file on app launch.
    /// Keeps last 6 backup sets.
    func backupDatabase() {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupportURL.appendingPathComponent("default.store")

        // Ensure database exists
        guard fileManager.fileExists(atPath: storeURL.path) else { return }

        // Create backup directory
        let backupDirURL = appSupportURL.appendingPathComponent(backupDirectoryName)
        do {
            try fileManager.createDirectory(at: backupDirURL, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Failed to create backup directory: \(error)")
            return
        }

        // Generate timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        
        let filesToBackup = ["default.store", "default.store-wal", "default.store-shm"]
        
        for filename in filesToBackup {
            let sourceURL = appSupportURL.appendingPathComponent(filename)
            let backupFilename = filename.replacingOccurrences(of: "default", with: "default-\(timestamp)")
            let destinationURL = backupDirURL.appendingPathComponent(backupFilename)
            
            if fileManager.fileExists(atPath: sourceURL.path) {
                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    print("✅ Backed up \(filename) to \(destinationURL.path)")
                } catch {
                    print("⚠️ Failed to backup \(filename): \(error)")
                }
            }
        }
            
        // Cleanup old backups (keep last 6 sets)
        cleanOldBackups(in: backupDirURL)
    }

    // MARK: - Helpers

    /// Find the newest backup timestamp in the backup directory.
    private func latestBackupTimestamp(in directory: URL) -> String? {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            var timestamps: Set<String> = []
            for file in files {
                let name = file.lastPathComponent
                if name.hasPrefix("default-") {
                    let parts = name.components(separatedBy: ".store")
                    if parts.count > 1 {
                        let prefix = parts[0]
                        if prefix.count > 8 {
                            let timestamp = String(prefix.dropFirst(8)) // remove "default-"
                            timestamps.insert(timestamp)
                        }
                    }
                }
            }
            return timestamps.sorted(by: >).first
        } catch {
            print("⚠️ Failed to list backup directory: \(error)")
            return nil
        }
    }

    private func cleanOldBackups(in directory: URL) {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            // Extract unique timestamps from filenames
            var timestamps: Set<String> = []
            for file in files {
                let name = file.lastPathComponent
                if name.hasPrefix("default-") {
                    let parts = name.components(separatedBy: ".store")
                    if parts.count > 1 {
                        let prefix = parts[0]
                        if prefix.count > 8 {
                            let timestamp = String(prefix.dropFirst(8))
                            timestamps.insert(timestamp)
                        }
                    }
                }
            }
            
            // Sort timestamps descending (newest first)
            let sortedTimestamps = timestamps.sorted(by: >)
            
            // Keep the newest 6 sets, delete the rest
            if sortedTimestamps.count > 6 {
                let timestampsToDelete = Set(sortedTimestamps.dropFirst(6))
                
                for file in files {
                    let name = file.lastPathComponent
                    for ts in timestampsToDelete {
                        if name.contains(ts) {
                            try fileManager.removeItem(at: file)
                            print("🗑️ Removed old backup file: \(name)")
                            break
                        }
                    }
                }
            }
        } catch {
            print("⚠️ Failed to cleanup backups: \(error)")
        }
    }
}
