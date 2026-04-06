import SwiftUI

struct FilterPanelView: View {
    @Bindable var viewModel: LedgerViewModel
    var categoryItems: [CategoryItem]

    private var expenseCategories: [String] {
        categoryItems.filter { $0.type == "expense" }.map(\.name)
    }
    private var incomeCategories: [String] {
        categoryItems.filter { $0.type == "income" }.map(\.name)
    }
    private var allCategories: [String] {
        categoryItems.map(\.name)
    }

    private func color(for name: String) -> Color {
        categoryItems.first(where: { $0.name == name })?.color ?? .gray
    }

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
                        HStack(spacing: 4) {
                            DatePicker("", selection: Binding(
                                get: { viewModel.filterDateStart ?? Date() },
                                set: { viewModel.filterDateStart = Calendar.current.startOfDay(for: $0) }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(width: 130)

                            if viewModel.filterDateStart != nil {
                                Button {
                                    viewModel.filterDateStart = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("–").foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            DatePicker("", selection: Binding(
                                get: { viewModel.filterDateEnd ?? Date() },
                                set: { viewModel.filterDateEnd = Calendar.current.startOfDay(for: $0) }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(width: 130)

                            if viewModel.filterDateEnd != nil {
                                Button {
                                    viewModel.filterDateEnd = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                        viewModel.selectedCategories = Set(allCategories)
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
                    categoryRow(categories: expenseCategories)

                    Text("Income").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    categoryRow(categories: incomeCategories)
                }
            }

            // Reset button
            HStack {
                Spacer()
                Button("Reset") { viewModel.resetFilters() }
                    .buttonStyle(.bordered)
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
                let catColor = color(for: cat)
                Button {
                    if isOn { viewModel.selectedCategories.remove(cat) }
                    else { viewModel.selectedCategories.insert(cat) }
                } label: {
                    Text(cat)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? catColor.opacity(0.15) : Color.clear)
                        .foregroundStyle(isOn ? catColor : .secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isOn ? catColor.opacity(0.4) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

