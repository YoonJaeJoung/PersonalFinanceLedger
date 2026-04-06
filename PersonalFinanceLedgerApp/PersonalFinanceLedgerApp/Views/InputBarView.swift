import SwiftUI
import SwiftData

struct InputBarView: View {
    @Bindable var viewModel: LedgerViewModel
    var categoryItems: [CategoryItem]
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isCategoryFocused: Bool
    @State private var suggestionsHeight: CGFloat = 0

    private var currentCategoryNames: [String] {
        let type = viewModel.isExpense ? "expense" : "income"
        return categoryItems.filter { $0.type == type }.map(\.name)
    }

    private func color(for name: String) -> Color {
        categoryItems.first(where: { $0.name == name })?.color ?? .gray
    }

    private var categorySuggestions: [String] {
        let query = viewModel.inputCategory.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty, isCategoryFocused else { return [] }
        return currentCategoryNames.filter {
            $0.lowercased().hasPrefix(query) && $0 != viewModel.inputCategory
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Expense / Income toggle
            Button {
                viewModel.isExpense.toggle()
                if !viewModel.inputCategory.isEmpty {
                    viewModel.inputCategory = ""
                }
            } label: {
                Text(viewModel.isExpense ? "Expense" : "Income")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.isExpense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(viewModel.isExpense ? .red : .green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(viewModel.isExpense ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                    )
            }
            .buttonStyle(.plain)

            // Account picker
            Picker("", selection: $viewModel.inputAccount) {
                ForEach(viewModel.dynamicAccounts, id: \.self) { account in
                    Text(account).tag(account)
                }
            }
            .frame(width: 100)

            // Date picker
            DatePicker("", selection: $viewModel.inputDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: 110)

            // Description
            TextField("Description", text: $viewModel.inputDescription)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 120)

            // Category with autocomplete (overlay, not popover)
            categoryField

            // Amount
            TextField("Amount", text: $viewModel.inputAmount)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onSubmit { viewModel.submitRow(context: modelContext) }

            // Add button
            Button("Add") {
                viewModel.submitRow(context: modelContext)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var categoryField: some View {
        // Keep the TextField in the layout; render suggestions as an overlay above it so they don't affect layout.
        VStack(alignment: .leading, spacing: 0) {
            TextField("Category", text: $viewModel.inputCategory)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
                .focused($isCategoryFocused)
                .onKeyPress(.tab) {
                    if let first = categorySuggestions.first {
                        viewModel.inputCategory = first
                        return .handled
                    }
                    return .ignored
                }
        }
        .overlay(alignment: .topLeading) {
            if !categorySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categorySuggestions, id: \.self) { cat in
                        Button {
                            viewModel.inputCategory = cat
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
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .frame(width: 160)
                // Measure the overlay height so we can place it above the text field without affecting layout
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { suggestionsHeight = geo.size.height }
                            .onChange(of: categorySuggestions) { _, _ in
                                suggestionsHeight = geo.size.height
                            }
                    }
                )
                // Position the overlay above the text field with a small gap
                .offset(y: -(suggestionsHeight + 6))
                .zIndex(10)
            }
        }
    }
}


