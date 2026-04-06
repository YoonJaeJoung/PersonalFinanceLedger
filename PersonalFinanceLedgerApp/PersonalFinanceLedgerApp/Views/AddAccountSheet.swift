import SwiftUI
import SwiftData

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

        let descriptor = FetchDescriptor<AccountItem>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let maxOrder = existing.map(\.sortOrder).max() ?? -1

        // Generate a CSV filename from the name
        let csvName = trimmed.lowercased().replacingOccurrences(of: " ", with: "_") + ".csv"

        let item = AccountItem(name: trimmed, csvFileName: csvName, sortOrder: maxOrder + 1)
        modelContext.insert(item)
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save new account: \(error)")
        }
    }
}
