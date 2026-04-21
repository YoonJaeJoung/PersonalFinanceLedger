import SwiftUI

struct TransactionListView: View {
    @Environment(LedgerStore.self) private var store
    @Bindable var viewModel: LedgerViewModel
    let allTransactions: [Transaction]
    let categoryItems: [CategoryItem]
    let accountItems: [AccountItem]

    private var filtered: [Transaction] {
        viewModel.filteredTransactions(from: allTransactions)
    }

    private var balance: Double {
        viewModel.balance(of: filtered)
    }

    private var selectedCount: Int {
        viewModel.selectedTransactionIDs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar bar
            toolbarBar

            // Filter panel (collapsible)
            if viewModel.isFilterPanelOpen {
                FilterPanelView(viewModel: viewModel, categoryItems: categoryItems)
                Divider()
            }

            // Table
            if filtered.isEmpty {
                Spacer()
                Text(viewModel.selectedAccounts.isEmpty
                     ? "Select at least one account"
                     : "No matching records")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                Spacer()
            } else {
                Table(of: Transaction.self, selection: $viewModel.selectedTransactionIDs) {
                    TableColumn("Date") { t in
                        Text(t.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.callout)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.editingTransaction = t
                            }
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Category") { t in
                        CategoryBadge(category: t.category, categoryItems: categoryItems)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.editingTransaction = t
                            }
                    }
                    .width(min: 90, ideal: 120)

                    TableColumn("Description") { t in
                        Text(t.descriptionText)
                            .font(.callout)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.editingTransaction = t
                            }
                    }

                    TableColumn("Account") { t in
                        Text(t.account)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.editingTransaction = t
                            }
                    }
                    .width(min: 60, ideal: 90)

                    TableColumn("Amount") { t in
                        Text(t.displayAmount)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(t.amount >= 0 ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.editingTransaction = t
                            }
                    }
                    .width(min: 70, ideal: 100)
                } rows: {
                    ForEach(filtered) { transaction in
                        TableRow(transaction)
                            .contextMenu {
                                Button("Edit") {
                                    viewModel.editingTransaction = transaction
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    store.deleteTransaction(id: transaction.id)
                                }
                            }
                    }
                }
            }

            Divider()

            // Balance bar
            HStack {
                Text("Balance")
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "$%.2f", abs(balance)))
                    .fontWeight(.semibold)
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.blue.opacity(0.06))

            Divider()

            // Input bar
            InputBarView(viewModel: viewModel, categoryItems: categoryItems)
        }
        .sheet(item: $viewModel.editingTransaction) { transaction in
            EditTransactionSheet(transaction: transaction, categoryItems: categoryItems, viewModel: viewModel)
        }
    }

    // MARK: - Toolbar bar
    private var toolbarBar: some View {
        HStack(spacing: 8) {
            // Filter toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isFilterPanelOpen.toggle()
                }
            } label: {
                Label(viewModel.isFilterPanelOpen ? "Hide Filters" : "Filters",
                      systemImage: "line.3.horizontal.decrease")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(viewModel.isFilterPanelOpen ? .accentColor : nil)

            Spacer()

            // Selection actions
            if selectedCount > 0 {
                // Move to account
                Picker("Move to", selection: $viewModel.moveTargetAccount) {
                    ForEach(viewModel.dynamicAccounts, id: \.self) { acc in
                        Text(acc).tag(acc)
                    }
                }
                .frame(width: 120)

                Button {
                    viewModel.moveSelected(to: viewModel.moveTargetAccount, store: store)
                } label: {
                    Label("Move (\(selectedCount))", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Delete
                Button(role: .destructive) {
                    viewModel.deleteSelected(store: store)
                } label: {
                    Label("Delete (\(selectedCount))", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
