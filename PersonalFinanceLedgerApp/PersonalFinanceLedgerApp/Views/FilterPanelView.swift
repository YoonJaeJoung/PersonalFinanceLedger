import SwiftUI

struct FilterPanelView: View {
    @Bindable var viewModel: LedgerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Description, Amount, Date filters
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DESCRIPTION").font(.caption2).foregroundStyle(.secondary)
                    TextField("Search...", text: $viewModel.filterDescription)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AMOUNT").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("Min", text: $viewModel.filterAmountMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text("–").foregroundStyle(.secondary)
                        TextField("Max", text: $viewModel.filterAmountMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE RANGE").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        DatePicker("", selection: Binding(
                            get: { viewModel.filterDateStart ?? Date.distantPast },
                            set: { viewModel.filterDateStart = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 110)

                        Text("–").foregroundStyle(.secondary)

                        DatePicker("", selection: Binding(
                            get: { viewModel.filterDateEnd ?? Date.distantFuture },
                            set: { viewModel.filterDateEnd = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 110)
                    }
                }

                Spacer()
            }

            // Category filter
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CATEGORY").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") {
                        viewModel.selectedCategories = Set(CategoryInfo.allCategories)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)

                    Button("Deselect All") {
                        viewModel.selectedCategories.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    categoryRow(categories: CategoryInfo.expenseCategories)

                    Text("Income").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    categoryRow(categories: CategoryInfo.incomeCategories)
                }
            }

            // Apply / Reset buttons
            HStack {
                Spacer()
                Button("Reset") { viewModel.resetFilters() }
                    .buttonStyle(.bordered)
                Button("Apply") { /* filters are live */ }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.bar)
    }

    @ViewBuilder
    func categoryRow(categories: [String]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(categories, id: \.self) { cat in
                let isOn = viewModel.selectedCategories.contains(cat)
                let color = CategoryInfo.color(for: cat)
                Button {
                    if isOn { viewModel.selectedCategories.remove(cat) }
                    else { viewModel.selectedCategories.insert(cat) }
                } label: {
                    Text(cat)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? color.opacity(0.15) : Color.clear)
                        .foregroundStyle(isOn ? color : .secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isOn ? color.opacity(0.4) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
