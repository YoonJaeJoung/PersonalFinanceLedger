import SwiftUI
import Charts
import SwiftData

// MARK: - Data Structs

struct CategoryExpense: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
}

struct CategoryBreakdown: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
}

struct MonthExpense: Identifiable {
    let id = UUID()
    let label: String
    let sortDate: Date
    let totalAmount: Double
    let breakdowns: [CategoryBreakdown]
}

struct DayOfWeekExpense: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let label: String
    let totalAmount: Double
    let breakdowns: [CategoryBreakdown]
}

struct WeekExpense: Identifiable {
    let id = UUID()
    let label: String
    let weekStart: Date
    let totalAmount: Double
    let breakdowns: [CategoryBreakdown]
}

/// Flattened entry for stacked bar charts
struct StackedBarEntry: Identifiable {
    let id = UUID()
    let periodLabel: String
    let category: String
    let amount: Double
}

// MARK: - Summary Tab Picker

enum SummarySection: String, CaseIterable, Identifiable {
    case total = "Total"
    case month = "Month"
    case week  = "Week"
    case day   = "Day"
    var id: String { rawValue }
}

// MARK: - Main SummaryView

struct SummaryView: View {
    let transactions: [Transaction]
    let allTransactions: [Transaction]
    let categoryItems: [CategoryItem]
    let accountItems: [AccountItem]
    let viewModel: LedgerViewModel

    @State private var selectedSection: SummarySection = .total
    @State private var showExcludedRefunds = false

    // Cached refund matching (computed once on appear, cleared on disappear)
    @State private var cachedRefundMatchedIDs: Set<PersistentIdentifier> = []

    // MARK: Refund Matching (computed once, stored in cache)

    private static func computeRefundMatches(from transactions: [Transaction]) -> Set<PersistentIdentifier> {
        let refunds = transactions.filter { $0.amount > 0 && $0.category == "Refund" }
        let expenseTxns = transactions.filter { $0.amount < 0 }

        var matched = Set<PersistentIdentifier>()
        var usedRefunds = Set<PersistentIdentifier>()

        for refund in refunds {
            guard !usedRefunds.contains(refund.persistentModelID) else { continue }
            let refundWords = Set(
                refund.descriptionText.lowercased()
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
            )

            for expense in expenseTxns {
                guard !matched.contains(expense.persistentModelID) else { continue }
                if abs(abs(refund.amount) - abs(expense.amount)) < 0.001 {
                    let expenseWords = Set(
                        expense.descriptionText.lowercased()
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                    )
                    if !refundWords.isDisjoint(with: expenseWords) {
                        matched.insert(expense.persistentModelID)
                        usedRefunds.insert(refund.persistentModelID)
                        break
                    }
                }
            }
        }
        return matched
    }

    private var excludedRefundExpenses: [Transaction] {
        transactions.filter { cachedRefundMatchedIDs.contains($0.persistentModelID) }
            .sorted { $0.date < $1.date }
    }

    // Filtered expenses (negative amounts, excluding refund-matched)
    private var expenses: [Transaction] {
        transactions.filter { $0.amount < 0 && !cachedRefundMatchedIDs.contains($0.persistentModelID) }
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + abs($1.amount) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Picker("View", selection: $selectedSection) {
                ForEach(SummarySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .total:
                        TotalSummaryCard(
                            data: categoryData,
                            total: totalExpenses
                        )
                    case .month:
                        MonthSummaryCard(
                            data: monthData,
                            total: totalExpenses,
                            colorMap: categoryColorMap
                        )
                    case .week:
                        WeekSummaryCard(
                            data: weekData,
                            total: totalExpenses,
                            colorMap: categoryColorMap
                        )
                    case .day:
                        DaySummaryCard(
                            data: dayOfWeekData,
                            total: totalExpenses,
                            averagePerDay: averagePerDay,
                            colorMap: categoryColorMap
                        )
                    }

                    // Excluded refund expenses section
                    if !excludedRefundExpenses.isEmpty {
                        excludedRefundsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            cachedRefundMatchedIDs = Self.computeRefundMatches(from: transactions)
        }
        .onDisappear {
            cachedRefundMatchedIDs = []
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Expense Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(expenses.count) expense transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                PDFExporter.exportPDF(
                    transactions: transactions,
                    allTransactions: allTransactions,
                    categoryItems: categoryItems,
                    accountItems: accountItems,
                    viewModel: viewModel,
                    refundMatchedIDs: cachedRefundMatchedIDs
                )
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "$%.2f", totalExpenses))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }

    // MARK: - Excluded Refunds Section

    private var excludedRefundsSection: some View {
        SummaryCard(title: "Excluded Refund-Matched Expenses", systemImage: "arrow.uturn.backward.circle") {
            DisclosureGroup(isExpanded: $showExcludedRefunds) {
                ForEach(excludedRefundExpenses, id: \.persistentModelID) { t in
                    HStack(spacing: 8) {
                        Text(t.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        Circle()
                            .fill(viewModel.dynamicColor(for: t.category))
                            .frame(width: 8, height: 8)
                        Text(t.category)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        Text(t.descriptionText)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "$%.2f", abs(t.amount)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 1)
                }
            } label: {
                Text("\(excludedRefundExpenses.count) expenses matched to refunds")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data Aggregation

    private var categoryColorMap: [String: Color] {
        viewModel.dynamicCategoryColors
    }

    private func categoryBreakdowns(for txns: [Transaction]) -> [CategoryBreakdown] {
        var dict: [String: Double] = [:]
        for t in txns {
            dict[t.category, default: 0] += abs(t.amount)
        }
        return dict.map { key, value in
            CategoryBreakdown(
                category: key,
                amount: value,
                color: viewModel.dynamicColor(for: key)
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var categoryData: [CategoryExpense] {
        var dict: [String: Double] = [:]
        for t in expenses {
            dict[t.category, default: 0] += abs(t.amount)
        }
        return dict.map { key, value in
            CategoryExpense(category: key, amount: value, color: viewModel.dynamicColor(for: key))
        }
        .sorted { $0.amount > $1.amount }
    }

    private var monthData: [MonthExpense] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        var grouped: [DateComponents: [Transaction]] = [:]
        for t in expenses {
            let comps = calendar.dateComponents([.year, .month], from: t.date)
            grouped[comps, default: []].append(t)
        }

        return grouped.compactMap { comps, txns in
            guard let date = calendar.date(from: comps) else { return nil }
            let total = txns.reduce(0) { $0 + abs($1.amount) }
            return MonthExpense(
                label: formatter.string(from: date),
                sortDate: date,
                totalAmount: total,
                breakdowns: categoryBreakdowns(for: txns)
            )
        }
        .sorted { $0.sortDate < $1.sortDate }
    }

    private var dayOfWeekData: [DayOfWeekExpense] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols

        var grouped: [Int: [Transaction]] = [:]
        for t in expenses {
            let weekday = calendar.component(.weekday, from: t.date)
            grouped[weekday, default: []].append(t)
        }

        let orderedDays = [2, 3, 4, 5, 6, 7, 1]
        return orderedDays.map { dayIndex in
            let txns = grouped[dayIndex] ?? []
            let total = txns.reduce(0) { $0 + abs($1.amount) }
            return DayOfWeekExpense(
                dayIndex: dayIndex,
                label: symbols[dayIndex - 1],
                totalAmount: total,
                breakdowns: categoryBreakdowns(for: txns)
            )
        }
    }

    private var weekData: [WeekExpense] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "'W'ww yyyy"

        var grouped: [Date: [Transaction]] = [:]
        for t in expenses {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: t.date) else { continue }
            grouped[interval.start, default: []].append(t)
        }

        return grouped.map { weekStart, txns in
            let total = txns.reduce(0) { $0 + abs($1.amount) }
            return WeekExpense(
                label: formatter.string(from: weekStart),
                weekStart: weekStart,
                totalAmount: total,
                breakdowns: categoryBreakdowns(for: txns)
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    private var averagePerDay: Double {
        let calendar = Calendar.current
        let uniqueDates = Set(expenses.map { calendar.startOfDay(for: $0.date) })
        return uniqueDates.isEmpty ? 0 : totalExpenses / Double(uniqueDates.count)
    }
}

// MARK: - Card Container

struct SummaryCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Total Summary (formerly Category)

struct TotalSummaryCard: View {
    let data: [CategoryExpense]
    let total: Double

    var body: some View {
        SummaryCard(title: "Expenses by Category", systemImage: "tag.fill") {
            if data.isEmpty {
                emptyState
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 4) {
                        Text(String(format: "$%.0f", item.amount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(orientation: .vertical)
                            .font(.caption2)
                    }
                }
                .frame(height: 260)

                Divider()

                ForEach(data) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        Text(item.category)
                            .font(.callout)
                        Spacer()
                        Text(String(format: "$%.2f", item.amount))
                            .font(.callout)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        Text(String(format: "(%.1f%%)", total > 0 ? item.amount / total * 100 : 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Stacked Bar Detail View

struct StackedBarDetail: View {
    let label: String
    let breakdowns: [CategoryBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.bottom, 2)

            ForEach(breakdowns) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.category)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "$%.2f", item.amount))
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Month Summary

struct MonthSummaryCard: View {
    let data: [MonthExpense]
    let total: Double
    let colorMap: [String: Color]

    @State private var selectedMonth: String? = nil

    private var maxMonth: MonthExpense? {
        data.max(by: { $0.totalAmount < $1.totalAmount })
    }

    private var average: Double {
        data.isEmpty ? 0 : total / Double(data.count)
    }

    private var flatEntries: [StackedBarEntry] {
        data.flatMap { month in
            month.breakdowns.map { b in
                StackedBarEntry(periodLabel: month.label, category: b.category, amount: b.amount)
            }
        }
    }

    private var uniqueCategories: [String] {
        var seen = Set<String>()
        return flatEntries.compactMap { e in
            if seen.contains(e.category) { return nil }
            seen.insert(e.category)
            return e.category
        }
    }

    private var uniqueColors: [Color] {
        uniqueCategories.map { colorMap[$0] ?? .gray }
    }

    var body: some View {
        SummaryCard(title: "Expenses by Month", systemImage: "calendar") {
            if data.isEmpty {
                emptyState
            } else {
                HStack(spacing: 12) {
                    statChip(label: "Average/mo", value: String(format: "$%.0f", average), color: .blue)
                    if let m = maxMonth {
                        statChip(label: "Highest", value: m.label, color: .red)
                    }
                }

                Chart(flatEntries) { entry in
                    BarMark(
                        x: .value("Month", entry.periodLabel),
                        y: .value("Amount", entry.amount)
                    )
                    .foregroundStyle(by: .value("Category", entry.category))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(domain: uniqueCategories, range: uniqueColors)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(orientation: .vertical).font(.caption2)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let origin = geometry[proxy.plotAreaFrame].origin
                                let x = location.x - origin.x
                                if let label: String = proxy.value(atX: x) {
                                    selectedMonth = (selectedMonth == label) ? nil : label
                                }
                            }
                    }
                }
                .frame(height: 220)

                if let sel = selectedMonth, let monthItem = data.first(where: { $0.label == sel }) {
                    StackedBarDetail(label: sel, breakdowns: monthItem.breakdowns)
                }
            }
        }
    }
}

// MARK: - Day of Week Summary

struct DaySummaryCard: View {
    let data: [DayOfWeekExpense]
    let total: Double
    let averagePerDay: Double
    let colorMap: [String: Color]

    @State private var selectedDay: String? = nil

    private var busiestDay: DayOfWeekExpense? {
        data.max(by: { $0.totalAmount < $1.totalAmount })
    }

    private var flatEntries: [StackedBarEntry] {
        data.flatMap { day in
            day.breakdowns.map { b in
                StackedBarEntry(periodLabel: day.label, category: b.category, amount: b.amount)
            }
        }
    }

    private var uniqueCategories: [String] {
        var seen = Set<String>()
        return flatEntries.compactMap { e in
            if seen.contains(e.category) { return nil }
            seen.insert(e.category)
            return e.category
        }
    }

    private var uniqueColors: [Color] {
        uniqueCategories.map { colorMap[$0] ?? .gray }
    }

    var body: some View {
        SummaryCard(title: "Expenses by Day of Week", systemImage: "clock.fill") {
            if data.allSatisfy({ $0.totalAmount == 0 }) {
                emptyState
            } else {
                HStack(spacing: 12) {
                    statChip(label: "Average/day", value: String(format: "$%.0f", averagePerDay), color: .blue)
                    if let b = busiestDay {
                        statChip(label: "Most spending", value: b.label, color: .red)
                    }
                }

                Chart(flatEntries) { entry in
                    BarMark(
                        x: .value("Day", entry.periodLabel),
                        y: .value("Amount", entry.amount)
                    )
                    .foregroundStyle(by: .value("Category", entry.category))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(domain: uniqueCategories, range: uniqueColors)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let origin = geometry[proxy.plotAreaFrame].origin
                                let x = location.x - origin.x
                                if let label: String = proxy.value(atX: x) {
                                    selectedDay = (selectedDay == label) ? nil : label
                                }
                            }
                    }
                }
                .frame(height: 220)

                if let sel = selectedDay, let dayItem = data.first(where: { $0.label == sel }) {
                    StackedBarDetail(label: sel, breakdowns: dayItem.breakdowns)
                }
            }
        }
    }
}

// MARK: - Week Summary

struct WeekSummaryCard: View {
    let data: [WeekExpense]
    let total: Double
    let colorMap: [String: Color]

    @State private var selectedWeek: String? = nil

    private var average: Double {
        data.isEmpty ? 0 : total / Double(data.count)
    }

    private var displayData: [WeekExpense] {
        data.count > 26 ? Array(data.suffix(26)) : data
    }

    private var flatEntries: [StackedBarEntry] {
        displayData.flatMap { week in
            week.breakdowns.map { b in
                StackedBarEntry(periodLabel: week.label, category: b.category, amount: b.amount)
            }
        }
    }

    private var uniqueCategories: [String] {
        var seen = Set<String>()
        return flatEntries.compactMap { e in
            if seen.contains(e.category) { return nil }
            seen.insert(e.category)
            return e.category
        }
    }

    private var uniqueColors: [Color] {
        uniqueCategories.map { colorMap[$0] ?? .gray }
    }

    var body: some View {
        SummaryCard(title: "Expenses by Week", systemImage: "chart.line.uptrend.xyaxis") {
            if data.isEmpty {
                emptyState
            } else {
                HStack(spacing: 12) {
                    statChip(label: "Average/wk", value: String(format: "$%.0f", average), color: .blue)
                    statChip(label: "Weeks tracked", value: "\(data.count)", color: .purple)
                }

                Chart {
                    ForEach(flatEntries) { entry in
                        BarMark(
                            x: .value("Week", entry.periodLabel),
                            y: .value("Amount", entry.amount)
                        )
                        .foregroundStyle(by: .value("Category", entry.category))
                        .cornerRadius(3)
                    }

                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .foregroundStyle(.orange)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .chartForegroundStyleScale(domain: uniqueCategories, range: uniqueColors)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(orientation: .vertical).font(.caption2)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let origin = geometry[proxy.plotAreaFrame].origin
                                let x = location.x - origin.x
                                if let label: String = proxy.value(atX: x) {
                                    selectedWeek = (selectedWeek == label) ? nil : label
                                }
                            }
                    }
                }
                .frame(height: 220)

                if data.count > 26 {
                    Text("Showing last 26 weeks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let sel = selectedWeek, let weekItem = displayData.first(where: { $0.label == sel }) {
                    StackedBarDetail(label: sel, breakdowns: weekItem.breakdowns)
                }
            }
        }
    }
}

// MARK: - Helpers

extension View {
    var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No expense data available")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }

    func statChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
