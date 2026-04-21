#if os(iOS)
import SwiftUI

struct iOSEditTransactionView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
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
        Form {
            Section {
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

                // Category with suggestions
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Category", text: $category)
                        .focused($isCategoryFocused)

                    if !categorySuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categorySuggestions, id: \.self) { cat in
                                    Button {
                                        category = cat
                                        isCategoryFocused = false
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(color(for: cat))
                                                .frame(width: 8, height: 8)
                                            Text(cat)
                                                .font(.callout)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(color(for: cat).opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Picker("Account", selection: $account) {
                    ForEach(viewModel.dynamicAccounts, id: \.self) { acc in
                        Text(acc).tag(acc)
                    }
                }

                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Edit Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var updated = transaction
        updated.date = date
        updated.descriptionText = descriptionText
        updated.category = category
        updated.account = account
        if let amt = Double(amount) {
            updated.amount = isExpense ? -abs(amt) : abs(amt)
        }
        store.updateTransaction(updated)
    }
}

#endif
