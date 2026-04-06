import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let transaction: Transaction
    var categoryItems: [CategoryItem]
    var viewModel: LedgerViewModel

    @State private var date: Date
    @State private var descriptionText: String
    @State private var category: String
    @State private var amount: String
    @State private var account: String
    @State private var isExpense: Bool
    @FocusState private var isCategoryFocused: Bool

    init(transaction: Transaction, categoryItems: [CategoryItem], viewModel: LedgerViewModel) {
        self.transaction = transaction
        self.categoryItems = categoryItems
        self.viewModel = viewModel
        _date = State(initialValue: transaction.date)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _category = State(initialValue: transaction.category)
        _amount = State(initialValue: String(format: "%.2f", abs(transaction.amount)))
        _account = State(initialValue: transaction.account)
        _isExpense = State(initialValue: transaction.amount < 0)
    }

    private var categories: [String] {
        let type = isExpense ? "expense" : "income"
        return categoryItems.filter { $0.type == type }.map(\.name)
    }

    private func color(for name: String) -> Color {
        categoryItems.first(where: { $0.name == name })?.color ?? .gray
    }

    private var categorySuggestions: [String] {
        let query = category.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty, isCategoryFocused else { return [] }
        return categories.filter { $0.lowercased().hasPrefix(query) && $0 != category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Edit Transaction")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                TextField("Description", text: $descriptionText)

                Picker("Type", selection: $isExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .onChange(of: isExpense) { _, _ in
                    if !categories.contains(category) {
                        category = categories.first ?? ""
                    }
                }

                // Category with autocomplete
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Category")
                        Spacer()
                        TextField("Category", text: $category)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .focused($isCategoryFocused)
                            .onKeyPress(.tab) {
                                if let first = categorySuggestions.first {
                                    category = first
                                    return .handled
                                }
                                return .ignored
                            }
                    }

                    if !categorySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(categorySuggestions, id: \.self) { cat in
                                Button {
                                    category = cat
                                    isCategoryFocused = false
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(color(for: cat))
                                            .frame(width: 8, height: 8)
                                        Text(cat)
                                            .font(.callout)
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if cat != categorySuggestions.last {
                                    Divider().padding(.horizontal, 8)
                                }
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                    }
                }

                Picker("Account", selection: $account) {
                    ForEach(viewModel.dynamicAccounts, id: \.self) { acc in
                        Text(acc).tag(acc)
                    }
                }

                TextField("Amount", text: $amount)
            }
            .formStyle(.grouped)
            .frame(width: 380, height: 360)

            // Footer buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Save") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 420)
    }

    private func save() {
        transaction.date = date
        transaction.descriptionText = descriptionText
        transaction.category = category
        transaction.account = account
        if let amt = Double(amount) {
            transaction.amount = isExpense ? -abs(amt) : abs(amt)
        }
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save edited transaction: \(error)")
        }
    }
}
