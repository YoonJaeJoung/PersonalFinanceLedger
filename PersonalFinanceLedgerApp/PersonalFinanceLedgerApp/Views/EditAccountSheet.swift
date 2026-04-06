import SwiftUI
import SwiftData

struct EditAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AccountItem.sortOrder) private var accounts: [AccountItem]
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]

    @State private var editingItem: AccountItem?
    @State private var editName = ""
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Accounts")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                ForEach(accounts) { acct in
                    accountRow(acct)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(width: 400, height: 250)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 430)
        .alert("Cannot Delete", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    @ViewBuilder
    private func accountRow(_ acct: AccountItem) -> some View {
        if editingItem?.persistentModelID == acct.persistentModelID {
            HStack(spacing: 8) {
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    saveEdit(acct)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel") {
                    editingItem = nil
                }
                .controlSize(.small)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(acct.name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editingItem = acct
                    editName = acct.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button(role: .destructive) {
                    deleteAccount(acct)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private func saveEdit(_ acct: AccountItem) {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let oldName = acct.name

        acct.name = trimmed

        // If name changed, update all transactions
        if oldName != trimmed {
            for t in allTransactions where t.account == oldName {
                t.account = trimmed
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save account edit: \(error)")
        }
        editingItem = nil
    }

    private func deleteAccount(_ acct: AccountItem) {
        let usageCount = allTransactions.filter { $0.account == acct.name }.count
        if usageCount > 0 {
            deleteErrorMessage = "Cannot delete \"\(acct.name)\" because it has \(usageCount) transaction(s). Move or delete them first."
            showDeleteError = true
        } else {
            modelContext.delete(acct)
            do {
                try modelContext.save()
            } catch {
                print("⚠️ Failed to save after deleting account: \(error)")
            }
        }
    }
}
