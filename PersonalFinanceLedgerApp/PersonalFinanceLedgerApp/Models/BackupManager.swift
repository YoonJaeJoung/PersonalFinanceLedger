import Foundation

/// Simplified backup manager for JSON-based persistence.
/// iCloud Drive provides its own versioning, but this keeps local backups as an extra safety net.
struct BackupManager {
    static let shared = BackupManager()

    private let fileManager = FileManager.default
    private let backupDirectoryName = "Backups"

    /// Back up JSON data files to a local backup directory.
    func backupJSONFiles() {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        // Find JSON files in iCloud container or local fallback
        let containerURL: URL
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            containerURL = iCloudURL
                .appendingPathComponent("Documents")
                .appendingPathComponent("PersonalFinanceLedger")
        } else {
            containerURL = appSupportURL.appendingPathComponent("PersonalFinanceLedger")
        }

        let filesToBackup = ["transactions.json", "categories.json", "accounts.json"]
        let hasAnyFile = filesToBackup.contains { fileManager.fileExists(atPath: containerURL.appendingPathComponent($0).path) }
        guard hasAnyFile else { return }

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

        for filename in filesToBackup {
            let sourceURL = containerURL.appendingPathComponent(filename)
            let backupFilename = filename.replacingOccurrences(of: ".json", with: "-\(timestamp).json")
            let destinationURL = backupDirURL.appendingPathComponent(backupFilename)

            if fileManager.fileExists(atPath: sourceURL.path) {
                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                } catch {
                    print("⚠️ Failed to backup \(filename): \(error)")
                }
            }
        }

        cleanOldBackups(in: backupDirURL)
    }

    // MARK: - Cleanup

    private func cleanOldBackups(in directory: URL) {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

            // Extract unique timestamps from filenames
            var timestamps: Set<String> = []
            for file in files {
                let name = file.lastPathComponent
                if name.hasSuffix(".json") {
                    // Pattern: transactions-2026-04-20T...json
                    if let dashRange = name.range(of: "-", options: [], range: name.startIndex..<name.endIndex) {
                        let afterDash = name[dashRange.upperBound...]
                        if let dotRange = afterDash.range(of: ".json") {
                            let timestamp = String(afterDash[..<dotRange.lowerBound])
                            if timestamp.count > 10 { // ISO8601 timestamps are long
                                timestamps.insert(timestamp)
                            }
                        }
                    }
                }
            }

            // Keep the newest 6 sets
            let sortedTimestamps = timestamps.sorted(by: >)
            if sortedTimestamps.count > 6 {
                let timestampsToDelete = Set(sortedTimestamps.dropFirst(6))
                for file in files {
                    let name = file.lastPathComponent
                    for ts in timestampsToDelete {
                        if name.contains(ts) {
                            try fileManager.removeItem(at: file)
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
