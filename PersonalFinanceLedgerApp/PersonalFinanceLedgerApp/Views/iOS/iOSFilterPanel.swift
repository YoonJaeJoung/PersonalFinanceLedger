#if os(iOS)
import SwiftUI

struct iOSFilterPanel: View {
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
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Description and Amount
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DESCRIPTION").font(.caption2).foregroundStyle(.secondary)
                    TextField("Search...", text: $viewModel.filterDescription)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AMOUNT").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("Min", text: $viewModel.filterAmountMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                        Text("–").foregroundStyle(.secondary)
                        TextField("Max", text: $viewModel.filterAmountMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                    }
                }
            }

            // Row 2: Date range
            HStack(spacing: 8) {
                Text("DATE").font(.caption2).foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    DatePicker("", selection: Binding(
                        get: { viewModel.filterDateStart ?? Date() },
                        set: { viewModel.filterDateStart = Calendar.current.startOfDay(for: $0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    if viewModel.filterDateStart != nil {
                        Button {
                            viewModel.filterDateStart = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
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

                    if viewModel.filterDateEnd != nil {
                        Button {
                            viewModel.filterDateEnd = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
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
                    Button("All") {
                        viewModel.selectedCategories = Set(allCategories)
                    }
                    .font(.caption)
                    Button("None") {
                        viewModel.selectedCategories.removeAll()
                    }
                    .font(.caption)
                    Button("Reset") {
                        viewModel.resetFilters()
                    }
                    .font(.caption)
                }

                Text("Expense").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                categoryScrollRow(categories: expenseCategories)

                Text("Income").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                categoryScrollRow(categories: incomeCategories)
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func categoryScrollRow(categories: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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
}

#endif
