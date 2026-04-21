import Foundation
import SwiftUI

/// Central data store that replaces SwiftData's ModelContainer + ModelContext.
/// Persists data as JSON files in iCloud Drive (or local fallback).
/// Conforms to @Observable so SwiftUI views react to data changes automatically.
@Observable
final class LedgerStore {

    // MARK: - In-memory data

    private(set) var transactions: [Transaction] = []
    private(set) var categories: [CategoryItem] = []
    private(set) var accounts: [AccountItem] = []

    // MARK: - Sorted accessors (replace @Query(sort:))

    var sortedTransactions: [Transaction] {
        transactions.sorted { $0.date < $1.date }
    }

    var sortedCategories: [CategoryItem] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedAccounts: [AccountItem] {
        accounts.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - File management

    private let fileManager = FileManager.default
    private var metadataQuery: NSMetadataQuery?

    /// Resolved container URL (iCloud or local fallback), cached after first access.
    private var containerURL: URL

    private var transactionsURL: URL { containerURL.appendingPathComponent("transactions.json") }
    private var categoriesURL: URL { containerURL.appendingPathComponent("categories.json") }
    private var accountsURL: URL { containerURL.appendingPathComponent("accounts.json") }

    // MARK: - Initialization

    init() {
        let url = LedgerStore.resolveContainerURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        self.containerURL = url
        loadAll()
        startMonitoringICloudChanges()
    }

    deinit {
        stopMonitoringICloudChanges()
    }

    // MARK: - Container URL Resolution

    private static func resolveContainerURL() -> URL {
        let fm = FileManager.default
        #if os(macOS)
        // Save directly to iCloud Drive folder (syncs automatically, no entitlement needed)
        let home = fm.homeDirectoryForCurrentUser
        let iCloudDrive = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            .appendingPathComponent("PersonalFinanceLedger")
        if fm.fileExists(atPath: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path) {
            return iCloudDrive
        }
        // Local fallback (iCloud Drive not available)
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PersonalFinanceLedger")
        #else
        // iOS: use app's Documents directory
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("PersonalFinanceLedger")
        #endif
    }

    // MARK: - JSON Read / Write with NSFileCoordinator

    private func readJSON<T: Decodable>(_ type: [T].Type, from url: URL) -> [T] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        var result: [T] = []
        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            result = (try? decoder.decode([T].self, from: data)) ?? []
        }

        if let coordError {
            print("⚠️ File coordination read error: \(coordError)")
        }
        return result
    }

    private func writeJSON<T: Encodable>(_ items: [T], to url: URL) {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(items) else { return }
            try? data.write(to: writeURL, options: .atomic)
        }

        if let coordError {
            print("⚠️ File coordination write error: \(coordError)")
        }
    }

    // MARK: - Load / Save

    func loadAll() {
        transactions = readJSON([Transaction].self, from: transactionsURL)
        categories = readJSON([CategoryItem].self, from: categoriesURL)
        accounts = readJSON([AccountItem].self, from: accountsURL)
    }

    func saveTransactions() {
        writeJSON(transactions, to: transactionsURL)
    }

    func saveCategories() {
        writeJSON(categories, to: categoriesURL)
    }

    func saveAccounts() {
        writeJSON(accounts, to: accountsURL)
    }

    // MARK: - Transaction CRUD

    func addTransaction(_ t: Transaction) {
        transactions.append(t)
        saveTransactions()
    }

    func addTransactions(_ batch: [Transaction]) {
        transactions.append(contentsOf: batch)
        saveTransactions()
    }

    func updateTransaction(_ t: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == t.id }) {
            transactions[index] = t
            saveTransactions()
        }
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        saveTransactions()
    }

    func deleteTransactions(ids: Set<UUID>) {
        transactions.removeAll { ids.contains($0.id) }
        saveTransactions()
    }

    // MARK: - Category CRUD

    func addCategory(_ c: CategoryItem) {
        categories.append(c)
        saveCategories()
    }

    func updateCategory(_ c: CategoryItem) {
        if let index = categories.firstIndex(where: { $0.id == c.id }) {
            categories[index] = c
            saveCategories()
        }
    }

    func deleteCategory(id: UUID) {
        categories.removeAll { $0.id == id }
        saveCategories()
    }

    func reorderCategories(type: String, orderedIDs: [UUID]) {
        for (newOrder, catID) in orderedIDs.enumerated() {
            if let idx = categories.firstIndex(where: { $0.id == catID }) {
                categories[idx].sortOrder = newOrder
            }
        }
        saveCategories()
    }

    /// Rename a category and propagate to all matching transactions.
    func renameCategory(oldName: String, newName: String, newColorHex: String, type: String, categoryID: UUID) {
        // Update the category item
        if let idx = categories.firstIndex(where: { $0.id == categoryID }) {
            categories[idx].name = newName
            categories[idx].colorHex = newColorHex
            saveCategories()
        }

        // Update matching transactions
        if oldName != newName {
            let isExpense = type == "expense"
            var changed = false
            for i in transactions.indices {
                if transactions[i].category == oldName {
                    let txIsExpense = transactions[i].amount < 0
                    if isExpense == txIsExpense {
                        transactions[i].category = newName
                        changed = true
                    }
                }
            }
            if changed { saveTransactions() }
        }
    }

    // MARK: - Account CRUD

    func addAccount(_ a: AccountItem) {
        accounts.append(a)
        saveAccounts()
    }

    func updateAccount(_ a: AccountItem) {
        if let index = accounts.firstIndex(where: { $0.id == a.id }) {
            accounts[index] = a
            saveAccounts()
        }
    }

    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
    }

    /// Rename an account and propagate to all matching transactions.
    func renameAccount(oldName: String, newName: String, accountID: UUID) {
        if let idx = accounts.firstIndex(where: { $0.id == accountID }) {
            accounts[idx].name = newName
            saveAccounts()
        }

        var changed = false
        for i in transactions.indices {
            if transactions[i].account == oldName {
                transactions[i].account = newName
                changed = true
            }
        }
        if changed { saveTransactions() }
    }

    // MARK: - Bulk Operations

    func moveTransactions(ids: Set<UUID>, toAccount: String) {
        for i in transactions.indices {
            if ids.contains(transactions[i].id) {
                transactions[i].account = toAccount
            }
        }
        saveTransactions()
    }

    /// Import categories from CSV with upsert logic.
    func importCategories(_ imported: [(name: String, type: String, colorHex: String, sortOrder: Int)]) {
        for item in imported {
            if let idx = categories.firstIndex(where: { $0.name == item.name && $0.type == item.type }) {
                categories[idx].sortOrder = item.sortOrder
                categories[idx].colorHex = item.colorHex
            } else {
                categories.append(CategoryItem(name: item.name, type: item.type, colorHex: item.colorHex, sortOrder: item.sortOrder))
            }
        }
        saveCategories()
    }

    func clearAllAndRestoreDefaults() {
        transactions = []
        categories = []
        accounts = []
        saveTransactions()
        saveCategories()
        saveAccounts()
        seedDefaultsIfNeeded()
    }

    func seedDefaultsIfNeeded() {
        if categories.isEmpty {
            for (i, cat) in CategoryInfo.defaultExpenseCategories.enumerated() {
                categories.append(CategoryItem(name: cat.name, type: "expense", colorHex: cat.hex, sortOrder: i))
            }
            for (i, cat) in CategoryInfo.defaultIncomeCategories.enumerated() {
                categories.append(CategoryItem(name: cat.name, type: "income", colorHex: cat.hex, sortOrder: i))
            }
            saveCategories()
        }
        if accounts.isEmpty {
            for (i, acct) in CategoryInfo.defaultAccounts.enumerated() {
                accounts.append(AccountItem(name: acct.name, csvFileName: acct.csv, sortOrder: i))
            }
            saveAccounts()
        }
    }

    func cleanupDuplicateCategories() {
        var seen = Set<String>()
        var cleaned = false
        categories = categories.filter { item in
            let key = "\(item.name)-\(item.type)"
            if seen.contains(key) {
                cleaned = true
                return false
            }
            seen.insert(key)
            return true
        }
        if cleaned { saveCategories() }
    }

    // MARK: - iCloud Change Monitoring

    private func startMonitoringICloudChanges() {
        guard fileManager.ubiquityIdentityToken != nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.loadAll()
        }

        query.start()
        metadataQuery = query
    }

    private func stopMonitoringICloudChanges() {
        metadataQuery?.stop()
        metadataQuery = nil
    }
}
