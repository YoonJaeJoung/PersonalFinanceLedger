import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction

    @State private var date: Date
    @State private var descriptionText: String
    @State private var category: String
    @State private var amount: String
    @State private var account: String
    @State private var isExpense: Bool

    init(transaction: Transaction) {
        self.transaction = transaction
        _date = State(initialValue: transaction.date)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _category = State(initialValue: transaction.category)
        _amount = State(initialValue: String(format: "%.2f", abs(transaction.amount)))
        _account = State(initialValue: transaction.account)
        _isExpense = State(initialValue: transaction.amount < 0)
    }

    private var categories: [String] {
        isExpense ? CategoryInfo.expenseCategories : CategoryInfo.incomeCategories
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
                .onChange(of: isExpense) {
                    if !categories.contains(category) {
                        category = categories.first ?? ""
                    }
                }

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        HStack {
                            Circle()
                                .fill(CategoryInfo.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                        }
                        .tag(cat)
                    }
                }

                Picker("Account", selection: $account) {
                    ForEach(CategoryInfo.accounts, id: \.self) { acc in
                        Text(acc).tag(acc)
                    }
                }

                TextField("Amount", text: $amount)
            }
            .formStyle(.grouped)
            .frame(width: 380, height: 320)

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
    }
}
