import SwiftUI

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerStore.self) private var store

    @State private var editingItem: CategoryItem?
    @State private var editName = ""
    @State private var editColor = Color.gray
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @FocusState private var isNameFocused: Bool

    private var categories: [CategoryItem] {
        store.sortedCategories
    }

    private var allTransactions: [Transaction] {
        store.sortedTransactions
    }

    private var expenseCategories: [CategoryItem] {
        categories.filter { $0.type == "expense" }
    }

    private var incomeCategories: [CategoryItem] {
        categories.filter { $0.type == "income" }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Categories")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                if !expenseCategories.isEmpty {
                    Section("Expense") {
                        ForEach(expenseCategories) { cat in
                            categoryRow(cat)
                        }
                        .onMove(perform: moveExpenseCategory)
                    }
                }
                if !incomeCategories.isEmpty {
                    Section("Income") {
                        ForEach(incomeCategories) { cat in
                            categoryRow(cat)
                        }
                        .onMove(perform: moveIncomeCategory)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(width: 450, height: 350)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .alert("Cannot Delete", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    @ViewBuilder
    private func categoryRow(_ cat: CategoryItem) -> some View {
        if editingItem?.id == cat.id {
            // Editing mode
            HStack(spacing: 8) {
                ColorPicker("", selection: $editColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 30)

                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .onAppear {
                        isNameFocused = true
                    }

                Button("Save") {
                    saveEdit(cat)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel") {
                    editingItem = nil
                }
                .controlSize(.small)
            }
        } else {
            // Display mode
            HStack(spacing: 8) {
                Circle()
                    .fill(cat.color)
                    .frame(width: 12, height: 12)

                Text(cat.name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(cat.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    editingItem = cat
                    editName = cat.name
                    editColor = cat.color
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button(role: .destructive) {
                    deleteCategory(cat)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private func saveEdit(_ cat: CategoryItem) {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let oldName = cat.name
        let newName = trimmed
        let newHex = editColor.toHex()

        store.renameCategory(
            oldName: oldName,
            newName: newName,
            newColorHex: newHex,
            type: cat.type,
            categoryID: cat.id
        )
        editingItem = nil
    }

    private func deleteCategory(_ cat: CategoryItem) {
        let usageCount = allTransactions.filter { $0.category == cat.name }.count
        if usageCount > 0 {
            deleteErrorMessage = "Cannot delete \"\(cat.name)\" because it is used by \(usageCount) transaction(s). Rename or reassign them first."
            showDeleteError = true
        } else {
            store.deleteCategory(id: cat.id)
        }
    }

    private func moveExpenseCategory(from source: IndexSet, to destination: Int) {
        var items = expenseCategories
        items.move(fromOffsets: source, toOffset: destination)
        store.reorderCategories(type: "expense", orderedIDs: items.map(\.id))
    }

    private func moveIncomeCategory(from source: IndexSet, to destination: Int) {
        var items = incomeCategories
        items.move(fromOffsets: source, toOffset: destination)
        store.reorderCategories(type: "income", orderedIDs: items.map(\.id))
    }
}
