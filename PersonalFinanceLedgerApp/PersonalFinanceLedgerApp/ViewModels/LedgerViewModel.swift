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

    var currentCategories: [String] {
        isExpense ? CategoryInfo.expenseCategories : CategoryInfo.incomeCategories
    }

    func filteredTransactions(from all: [Transaction]) -> [Transaction] {
        all.filter { t in
            guard selectedAccounts.contains(t.account) else { return false }
            if !filterDescription.isEmpty,
               !t.descriptionText.localizedCaseInsensitiveContains(filterDescription) {
                return false
            }
            guard selectedCategories.contains(t.category) else { return false }
            let absAmt = abs(t.amount)
            if let min = Double(filterAmountMin), absAmt < min { return false }
            if let max = Double(filterAmountMax), absAmt > max { return false }
            if let start = filterDateStart, t.date < start { return false }
            if let end = filterDateEnd, t.date > end { return false }
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
        selectedCategories = Set(CategoryInfo.allCategories)
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
        try? context.save()

        // Reset input
        inputDescription = ""
        inputCategory = ""
        inputAmount = ""
    }

    func deleteSelected(from transactions: [Transaction], context: ModelContext) {
        let toDelete = transactions.filter { selectedTransactionIDs.contains($0.persistentModelID) }
        for t in toDelete {
            context.delete(t)
        }
        try? context.save()
        selectedTransactionIDs.removeAll()
    }

    func moveSelected(from transactions: [Transaction], to targetAccount: String, context: ModelContext) {
        let toMove = transactions.filter { selectedTransactionIDs.contains($0.persistentModelID) }
        for t in toMove {
            t.account = targetAccount
        }
        try? context.save()
        selectedTransactionIDs.removeAll()
    }
}
