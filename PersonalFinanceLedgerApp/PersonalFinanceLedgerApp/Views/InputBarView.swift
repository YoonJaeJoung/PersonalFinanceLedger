import SwiftUI
import SwiftData

struct InputBarView: View {
    @Bindable var viewModel: LedgerViewModel
    @Environment(\.modelContext) private var modelContext

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
                ForEach(CategoryInfo.accounts, id: \.self) { account in
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

            // Category picker
            Picker("Category", selection: $viewModel.inputCategory) {
                Text("Select...").tag("")
                ForEach(viewModel.currentCategories, id: \.self) { cat in
                    HStack {
                        Circle()
                            .fill(CategoryInfo.color(for: cat))
                            .frame(width: 8, height: 8)
                        Text(cat)
                    }
                    .tag(cat)
                }
            }
            .frame(width: 140)

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
}
