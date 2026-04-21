import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerStore.self) private var store

    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Account")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                TextField("Account Name", text: $name)
            }
            .formStyle(.grouped)
            .frame(width: 360, height: 120)

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

        let maxOrder = store.accounts.map(\.sortOrder).max() ?? -1

        // Generate a CSV filename from the name
        let csvName = trimmed.lowercased().replacingOccurrences(of: " ", with: "_") + ".csv"

        let item = AccountItem(name: trimmed, csvFileName: csvName, sortOrder: maxOrder + 1)
        store.addAccount(item)
    }
}
