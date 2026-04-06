import Foundation
import SwiftUI
import SwiftData

@Observable
class LedgerViewModel {
    // Navigation
    enum Tab: String, CaseIterable {
        case data = "Data"
        case summary = "Summary"
    }
    var selectedTab: Tab = .data

    // Account filter
    var selectedAccounts: Set<String> = Set(CategoryInfo.accounts)

    // Filters
    var isFilterPanelOpen = false
    var filterDescription = ""
    var filterAmountMin = ""
    var filterAmountMax = ""
    var filterDateStart: Date? = nil
    var filterDateEnd: Date? = nil
    var selectedCategories: Set<String> = Set(CategoryInfo.allCategories)

    // Formatter and string proxies for live-updating date filters
    private static let filterDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Text proxies to allow immediate filtering as user types dates
    var filterDateStartText: String {
        get {
            if let d = filterDateStart {
                return Self.filterDateFormatter.string(from: d)
            }
            return ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                filterDateStart = nil
                return
            }
            if let parsed = Self.filterDateFormatter.date(from: trimmed) {
                // Normalize to the start of day
                filterDateStart = Calendar.current.startOfDay(for: parsed)
            }
            // If parsing fails, leave the previous date in place until the input becomes valid
        }
    }

    var filterDateEndText: String {
        get {
            if let d = filterDateEnd {
                return Self.filterDateFormatter.string(from: d)
            }
            return ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                filterDateEnd = nil
                return
            }
            if let parsed = Self.filterDateFormatter.date(from: trimmed) {
                // Normalize to the start of day (end is treated as exclusive at start of next day in filtering)
                filterDateEnd = Calendar.current.startOfDay(for: parsed)
            }
            // If parsing fails, leave the previous date in place until the input becomes valid
        }
    }

    // Table selection
    var selectedTransactionIDs = Set<PersistentIdentifier>()

    // Editing
    var editingTransaction: Transaction? = nil

    // Input form
    var isExpense = true
    var inputAccount: String = "Chase"
    var inputDate = Date()
    var inputDescription = ""
    var inputCategory = ""
    var inputAmount = ""

    // CSV Import
    var showingImporter = false
    var importMessage = ""
    var showingImportAlert = false

    // Move account
    var moveTargetAccount = "Chase"

    // Dynamic category/account data (populated from SwiftData)
    var dynamicExpenseCategories: [String] = CategoryInfo.expenseCategories
    var dynamicIncomeCategories: [String] = CategoryInfo.incomeCategories
    var dynamicAllCategories: [String] = CategoryInfo.allCategories
    var dynamicAccounts: [String] = CategoryInfo.accounts
    var dynamicCategoryColors: [String: Color] = CategoryInfo.categoryColors

    var currentCategories: [String] {
        isExpense ? dynamicExpenseCategories : dynamicIncomeCategories
    }

    /// Sync dynamic accounts from SwiftData query results
    func syncAccounts(_ accounts: [String]) {
        guard !accounts.isEmpty else { return }
        dynamicAccounts = accounts
        // Add any new accounts to the selected set
        for a in accounts {
            selectedAccounts.insert(a)
        }
        // Remove selected accounts that no longer exist
        selectedAccounts = selectedAccounts.intersection(Set(accounts))
        if let first = accounts.first, !accounts.contains(inputAccount) {
            inputAccount = first
        }
        if let first = accounts.first, !accounts.contains(moveTargetAccount) {
            moveTargetAccount = first
        }
    }

    /// Sync dynamic categories from SwiftData query results
    func syncCategories(_ items: [CategoryItem]) {
        guard !items.isEmpty else { return }
        dynamicExpenseCategories = items.filter { $0.type == "expense" }.map(\.name)
        dynamicIncomeCategories = items.filter { $0.type == "income" }.map(\.name)

        var allSet = Set(dynamicExpenseCategories)
        allSet.formUnion(dynamicIncomeCategories)
        dynamicAllCategories = allSet.sorted()

        // Update color map
        var colors: [String: Color] = [:]
        for item in items {
            colors[item.name] = item.color
        }
        dynamicCategoryColors = colors

        // Add new categories to selected set
        for c in dynamicAllCategories {
            selectedCategories.insert(c)
        }
        // Remove selected categories that no longer exist
        selectedCategories = selectedCategories.intersection(Set(dynamicAllCategories))
    }

    func filteredTransactions(from all: [Transaction]) -> [Transaction] {
        // Normalize date range to whole days: start at beginning of day, end is exclusive (start of the next day)
        let calendar = Calendar.current
        let normalizedStart: Date? = {
            guard let start = filterDateStart else { return nil }
            return calendar.startOfDay(for: start)
        }()
        let normalizedEndExclusive: Date? = {
            guard let end = filterDateEnd else { return nil }
            let endStartOfDay = calendar.startOfDay(for: end)
            return calendar.date(byAdding: .day, value: 1, to: endStartOfDay)
        }()

        return all.filter { t in
            guard selectedAccounts.contains(t.account) else { return false }
            if !filterDescription.isEmpty,
               !t.descriptionText.localizedCaseInsensitiveContains(filterDescription) {
                return false
            }
            guard selectedCategories.contains(t.category) else { return false }
            let absAmt = abs(t.amount)
            if let min = Double(filterAmountMin), absAmt < min { return false }
            if let max = Double(filterAmountMax), absAmt > max { return false }
            if let start = normalizedStart, t.date < start { return false }
            if let endExclusive = normalizedEndExclusive, t.date >= endExclusive { return false }
            return true
        }
        .sorted { $0.date < $1.date }
    }

    func balance(of transactions: [Transaction]) -> Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    func resetFilters() {
        filterDescription = ""
        filterAmountMin = ""
        filterAmountMax = ""
        filterDateStart = nil
        filterDateEnd = nil
        selectedCategories = Set(dynamicAllCategories)
    }

    func submitRow(context: ModelContext) {
        let desc = inputDescription.trimmingCharacters(in: .whitespaces)
        let cat = inputCategory.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty, !cat.isEmpty,
              let amountVal = Double(inputAmount), amountVal > 0 else { return }

        let finalAmount = isExpense ? -abs(amountVal) : abs(amountVal)
        let transaction = Transaction(
            date: inputDate,
            descriptionText: desc,
            category: cat,
            amount: finalAmount,
            account: inputAccount
        )
        context.insert(transaction)
        do {
            try context.save()
            // Reset input on successful save
            inputDescription = ""
            inputCategory = ""
            inputAmount = ""
        } catch {
            print("⚠️ Failed to save new transaction: \(error)")
        }
    }

    func deleteSelected(from transactions: [Transaction], context: ModelContext) {
        let toDelete = transactions.filter { selectedTransactionIDs.contains($0.persistentModelID) }
        for t in toDelete {
            context.delete(t)
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to save after deleting transactions: \(error)")
        }
        selectedTransactionIDs.removeAll()
    }

    func moveSelected(from transactions: [Transaction], to targetAccount: String, context: ModelContext) {
        let toMove = transactions.filter { selectedTransactionIDs.contains($0.persistentModelID) }
        for t in toMove {
            t.account = targetAccount
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to save after moving transactions: \(error)")
        }
        selectedTransactionIDs.removeAll()
    }

    func dynamicColor(for category: String) -> Color {
        dynamicCategoryColors[category] ?? .gray
    }
}

