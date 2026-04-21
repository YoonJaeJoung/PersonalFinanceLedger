#if os(iOS)
import SwiftUI

struct iOSInputBar: View {
    @Environment(LedgerStore.self) private var store
    @Bindable var viewModel: LedgerViewModel
    var categoryItems: [CategoryItem]
    @Binding var isPresented: Bool

    // Input state
    @State private var isExpense = true
    @State private var inputAccount = ""
    @State private var inputDate = Date()
    @State private var inputDescription = ""
    @State private var inputCategory = ""
    @State private var inputAmount = ""

    // Progressive field state
    enum InputField: Hashable {
        case description, category, amount
    }
    @State private var expandedField: InputField = .description
    @FocusState private var focusedField: InputField?

    // MARK: - Computed Properties

    private var currentCategoryNames: [String] {
        let type = isExpense ? "expense" : "income"
        return categoryItems.filter { $0.type == type }.map(\.name)
    }

    private func categoryColor(for name: String) -> Color {
        categoryItems.first(where: { $0.name == name })?.color ?? .gray
    }

    private var categorySuggestions: [String] {
        let query = inputCategory.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty, expandedField == .category else { return [] }
        return currentCategoryNames.filter {
            $0.lowercased().hasPrefix(query) && $0 != inputCategory
        }
    }

    private var canSubmit: Bool {
        !inputDescription.trimmingCharacters(in: .whitespaces).isEmpty
        && !inputCategory.trimmingCharacters(in: .whitespaces).isEmpty
        && (Double(inputAmount) ?? 0) > 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Category suggestions above input
            if expandedField == .category && !categorySuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categorySuggestions, id: \.self) { cat in
                            Button {
                                inputCategory = cat
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedField = .amount
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(categoryColor(for: cat))
                                        .frame(width: 8, height: 8)
                                    Text(cat)
                                        .font(.callout)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(categoryColor(for: cat).opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
            }

            Divider()

            // Row 1: Close + Expense/Income ... Account + Date
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isExpense.toggle()
                    inputCategory = ""
                } label: {
                    Text(isExpense ? "Expense" : "Income")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isExpense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundStyle(isExpense ? .red : .green)
                        .clipShape(Capsule())
                }

                Spacer()

                Menu {
                    ForEach(viewModel.dynamicAccounts, id: \.self) { acc in
                        Button(acc) { inputAccount = acc }
                    }
                } label: {
                    Text(inputAccount)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }

                DatePicker("", selection: $inputDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Row 2: Progressive fields + Submit
            HStack(spacing: 8) {
                descriptionFieldView
                categoryFieldView
                amountFieldView

                // Submit button
                Button {
                    submitEntry()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSubmit ? .blue : .gray.opacity(0.3))
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 4)
        }
        .background(.bar)
        .onAppear {
            setupDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .description
            }
        }
        .onChange(of: expandedField) { _, newField in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = newField
            }
        }
    }

    // MARK: - Progressive Field Views

    @ViewBuilder
    private var descriptionFieldView: some View {
        if expandedField == .description {
            TextField("Description", text: $inputDescription)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .description)
                .submitLabel(.next)
                .onSubmit {
                    if !inputDescription.isEmpty {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedField = .category
                        }
                    }
                }
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedField = .description
                }
            } label: {
                Text(inputDescription.isEmpty ? "Desc" : inputDescription)
                    .lineLimit(1)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var categoryFieldView: some View {
        if expandedField == .category {
            TextField("Category", text: $inputCategory)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .category)
                .submitLabel(.next)
                .onSubmit {
                    if !inputCategory.isEmpty {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedField = .amount
                        }
                    }
                }
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedField = .category
                }
            } label: {
                if inputCategory.isEmpty {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                } else {
                    Circle()
                        .fill(categoryColor(for: inputCategory))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(String(inputCategory.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var amountFieldView: some View {
        if expandedField == .amount {
            TextField("Amount", text: $inputAmount)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
        } else if !inputCategory.isEmpty {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedField = .amount
                }
            } label: {
                Text(inputAmount.isEmpty ? "$" : "$\(inputAmount)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func setupDefaults() {
        inputDate = Date()
        isExpense = true
        expandedField = .description

        // Default account to last used (most recent transaction before today)
        let today = Calendar.current.startOfDay(for: Date())
        if let recent = store.sortedTransactions.last(where: { $0.date < today }) {
            inputAccount = recent.account
        } else if let first = viewModel.dynamicAccounts.first {
            inputAccount = first
        }
    }

    private func submitEntry() {
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
        store.addTransaction(transaction)

        // Reset fields for next entry (keep account, date, expense/income)
        inputDescription = ""
        inputCategory = ""
        inputAmount = ""
        expandedField = .description
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .description
        }
    }
}

#endif
