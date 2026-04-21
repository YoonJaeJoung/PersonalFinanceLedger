import SwiftUI

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerStore.self) private var store

    @State private var name = ""
    @State private var type = "expense"
    @State private var selectedColor = Color.blue

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Category")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Picker("Type", selection: $type) {
                    Text("Expense").tag("expense")
                    Text("Income").tag("income")
                }

                TextField("Name", text: $name)

                ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .frame(width: 360, height: 200)

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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 400)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let maxOrder = store.categories.map(\.sortOrder).max() ?? -1

        let item = CategoryItem(
            name: trimmed,
            type: type,
            colorHex: selectedColor.toHex(),
            sortOrder: maxOrder + 1
        )
        store.addCategory(item)
    }
}
