#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#endif
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Bi‑weekly Period

struct BiweeklyPeriod {
    let startDate: Date
    let endDate: Date

    var label: String {
        let f1 = DateFormatter()
        f1.dateFormat = "MMM d"
        let f2 = DateFormatter()
        f2.dateFormat = "MMM d, yyyy"
        return "\(f1.string(from: startDate)) – \(f2.string(from: endDate))"
    }
}

// MARK: - PDF Exporter

struct PDFExporter {
    // Editable PDF Branding
    static let pdfTitle = "Yoonjae NYU Exchange Finance Ledger"
    static var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        let dateString = formatter.string(from: Date())
        return "Yoonjae_Finance_Ledger_\(dateString).pdf"
    }

    // Page constants
    static let pageW: CGFloat = 612
    static let pageH: CGFloat = 792
    static let margin: CGFloat = 40
    static let contentW: CGFloat = pageW - 2 * margin
    static let titleFont = PlatformFont.boldSystemFont(ofSize: 14)
    static let subtitleFont = PlatformFont.systemFont(ofSize: 11)
    static let headerFont = PlatformFont.boldSystemFont(ofSize: 9)
    static let bodyFont = PlatformFont.systemFont(ofSize: 9)
    static let smallFont = PlatformFont.systemFont(ofSize: 8)

    // Column widths for transaction table
    static let colDate: CGFloat = 70
    static let colCategory: CGFloat = 80
    static let colAccount: CGFloat = 65
    static let colAmount: CGFloat = 70
    static var colDescription: CGFloat { contentW - colDate - colCategory - colAccount - colAmount }

    static let rowH: CGFloat = 16
    static let headerH: CGFloat = 20

    // MARK: - Public entry point

    #if os(macOS)
    static func exportPDF(
        transactions: [Transaction],
        allTransactions: [Transaction],
        categoryItems: [CategoryItem],
        accountItems: [AccountItem],
        viewModel: LedgerViewModel,
        refundMatchedIDs: Set<UUID>
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = defaultFileName
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sortedTxns = transactions.sorted { $0.date < $1.date }

        guard let pdfData = generatePDF(
            transactions: sortedTxns,
            allTransactions: allTransactions,
            categoryItems: categoryItems,
            accountItems: accountItems,
            viewModel: viewModel,
            refundMatchedIDs: refundMatchedIDs
        ) else { return }

        try? pdfData.write(to: url)
    }
    #endif

    /// Generates PDF data (cross-platform). On macOS, called by `exportPDF`. On iOS, use with `.fileExporter`.
    static func generatePDFData(
        transactions: [Transaction],
        allTransactions: [Transaction],
        categoryItems: [CategoryItem],
        accountItems: [AccountItem],
        viewModel: LedgerViewModel,
        refundMatchedIDs: Set<UUID>
    ) -> Data? {
        let sortedTxns = transactions.sorted { $0.date < $1.date }
        return generatePDF(
            transactions: sortedTxns,
            allTransactions: allTransactions,
            categoryItems: categoryItems,
            accountItems: accountItems,
            viewModel: viewModel,
            refundMatchedIDs: refundMatchedIDs
        )
    }

    // MARK: - PDF Generation

    static func generatePDF(
        transactions: [Transaction],
        allTransactions: [Transaction],
        categoryItems: [CategoryItem],
        accountItems: [AccountItem],
        viewModel: LedgerViewModel,
        refundMatchedIDs: Set<UUID>
    ) -> Data? {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil as CFDictionary?) else { return nil }

        var pageNum = 0
        let periods = buildPeriods(from: transactions)

        for period in periods {
            let periodTxns = transactions.filter { t in
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: period.startDate)
                guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: period.endDate)) else { return false }
                return t.date >= start && t.date < endExclusive
            }

            guard !periodTxns.isEmpty else { continue }

            // --- First page of this period: chart + table ---
            pageNum += 1
            beginPage(ctx: ctx)

            var y = drawHeader(ctx: ctx, subtitle: period.label, pageNumber: pageNum)

            // Chart area (top 30% of remaining space)
            let remainingH = pageH - margin - y
            let chartH: CGFloat = remainingH * 0.3
            let chartRect = CGRect(x: margin, y: y, width: contentW, height: chartH)
            drawCategoryBarChart(ctx: ctx, rect: chartRect, transactions: periodTxns, categoryItems: categoryItems, viewModel: viewModel, refundMatchedIDs: refundMatchedIDs)

            y += chartH + 8

            // Period totals above table
            let periodExpense = periodTxns.filter { $0.amount < 0 && !refundMatchedIDs.contains($0.id) }
                .reduce(0.0) { $0 + abs($1.amount) }
            let periodIncome = periodTxns.filter { $0.amount > 0 && !refundMatchedIDs.contains($0.id) }
                .reduce(0.0) { $0 + $1.amount }
            drawText(ctx: ctx, text: String(format: "Total Expense: $%.2f", periodExpense),
                     rect: CGRect(x: margin, y: y, width: contentW / 2, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 9), color: .systemRed, alignment: .left)
            drawText(ctx: ctx, text: String(format: "Total Income: $%.2f", periodIncome),
                     rect: CGRect(x: margin + contentW / 2, y: y, width: contentW / 2, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 9), color: .systemGreen, alignment: .right)
            y += 18

            // Table area
            y = drawTableHeader(ctx: ctx, y: y)
            var txIndex = 0

            while txIndex < periodTxns.count {
                let bottomLimit = pageH - margin - 20 // leave room for page number
                if y + rowH > bottomLimit {
                    drawPageNumber(ctx: ctx, pageNumber: pageNum)
                    endPage(ctx: ctx)

                    // --- Overflow page (no chart) ---
                    pageNum += 1
                    beginPage(ctx: ctx)
                    y = drawHeader(ctx: ctx, subtitle: period.label + " (cont.)", pageNumber: pageNum)
                    y = drawTableHeader(ctx: ctx, y: y)
                }

                let t = periodTxns[txIndex]
                drawTransactionRow(ctx: ctx, transaction: t, y: y, viewModel: viewModel)
                y += rowH
                txIndex += 1
            }

            drawPageNumber(ctx: ctx, pageNumber: pageNum)
            endPage(ctx: ctx)
        }

        // --- LAST PAGE: Total Summary ---
        pageNum += 1
        beginPage(ctx: ctx)

        var y = drawHeader(ctx: ctx, subtitle: "Total Summary", pageNumber: pageNum)

        // Full-span category bar chart for entire date span
        let chartRect = CGRect(x: margin, y: y, width: contentW, height: 250)
        drawCategoryBarChart(ctx: ctx, rect: chartRect, transactions: transactions, categoryItems: categoryItems, viewModel: viewModel, refundMatchedIDs: refundMatchedIDs)
        y += 260

        // Account Status
        y += 10
        drawText(ctx: ctx, text: "Account Status", rect: CGRect(x: margin, y: y, width: contentW, height: 18),
                 font: PlatformFont.boldSystemFont(ofSize: 12), color: .black)
        y += 22

        let col1: CGFloat = margin            // Account name
        let col2: CGFloat = margin + 110      // Expense / Income / Balance label
        let col3: CGFloat = margin + 200      // Category name
        let col4: CGFloat = margin + 340      // Amount (right edge at margin + 430)
        let col4W: CGFloat = 90

        let expenseCategories = categoryItems.filter { $0.type == "expense" }.sorted { $0.sortOrder < $1.sortOrder }
        let incomeCategories = categoryItems.filter { $0.type == "income" }.sorted { $0.sortOrder < $1.sortOrder }

        for account in accountItems {
            let acctTxns = allTransactions.filter { $0.account == account.name }
            let balance = acctTxns.reduce(0.0) { $0 + $1.amount }
            let balColor: PlatformColor = balance >= 0 ? .systemGreen : .systemRed

            // Check for page overflow
            let estimatedHeight = CGFloat(expenseCategories.count + incomeCategories.count + 4) * 14 + 10
            if y + estimatedHeight > pageH - margin - 20 {
                drawPageNumber(ctx: ctx, pageNumber: pageNum)
                endPage(ctx: ctx)
                pageNum += 1
                beginPage(ctx: ctx)
                y = drawHeader(ctx: ctx, subtitle: "Total Summary (cont.)", pageNumber: pageNum)
            }

            // Account name (bold)
            drawText(ctx: ctx, text: account.name,
                     rect: CGRect(x: col1, y: y, width: 110, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 9), color: .label)

            // --- Expense section ---
            drawText(ctx: ctx, text: "Expense",
                     rect: CGRect(x: col2, y: y, width: 90, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 8), color: .systemRed)
            y += 14

            for cat in expenseCategories {
                let catTxns = acctTxns.filter { $0.category == cat.name && $0.amount < 0 && !refundMatchedIDs.contains($0.id) }
                let catTotal = catTxns.reduce(0.0) { $0 + abs($1.amount) }
                drawText(ctx: ctx, text: cat.name,
                         rect: CGRect(x: col3, y: y, width: 140, height: 13),
                         font: bodyFont, color: .label)
                drawText(ctx: ctx, text: String(format: "$%.2f", catTotal),
                         rect: CGRect(x: col4, y: y, width: col4W, height: 13),
                         font: bodyFont, color: catTotal > 0 ? .label : .tertiaryLabel, alignment: .right)
                y += 13
            }

            y += 4

            // --- Income section ---
            drawText(ctx: ctx, text: "Income",
                     rect: CGRect(x: col2, y: y, width: 90, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 8), color: .systemGreen)
            y += 14

            for cat in incomeCategories {
                let catTxns = acctTxns.filter { $0.category == cat.name && $0.amount > 0 && !refundMatchedIDs.contains($0.id) }
                let catTotal = catTxns.reduce(0.0) { $0 + $1.amount }
                drawText(ctx: ctx, text: cat.name,
                         rect: CGRect(x: col3, y: y, width: 140, height: 13),
                         font: bodyFont, color: .label)
                drawText(ctx: ctx, text: String(format: "$%.2f", catTotal),
                         rect: CGRect(x: col4, y: y, width: col4W, height: 13),
                         font: bodyFont, color: catTotal > 0 ? .label : .tertiaryLabel, alignment: .right)
                y += 13
            }

            y += 4

            // --- Balance ---
            drawText(ctx: ctx, text: "Balance",
                     rect: CGRect(x: col2, y: y, width: 90, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 9), color: .label)
            drawText(ctx: ctx, text: String(format: "$%.2f", abs(balance)),
                     rect: CGRect(x: col4, y: y, width: col4W, height: 14),
                     font: PlatformFont.boldSystemFont(ofSize: 9), color: balColor, alignment: .right)
            y += 14

            // Separator between accounts
            y += 6
            ctx.setStrokeColor(PlatformColor.separator.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin, y: y))
            ctx.addLine(to: CGPoint(x: pageW - margin, y: y))
            ctx.strokePath()
            y += 8
        }

        drawPageNumber(ctx: ctx, pageNumber: pageNum)
        endPage(ctx: ctx)

        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Period Building

    static func buildPeriods(from transactions: [Transaction]) -> [BiweeklyPeriod] {
        guard let earliest = transactions.map(\.date).min(),
              let latest = transactions.map(\.date).max() else { return [] }

        let calendar = Calendar.current
        var periods: [BiweeklyPeriod] = []

        var comps = calendar.dateComponents([.year, .month], from: earliest)
        comps.day = 1
        guard var current = calendar.date(from: comps) else { return [] }

        while current <= latest {
            let year = calendar.component(.year, from: current)
            let month = calendar.component(.month, from: current)

            // First half: 1–15
            if let s = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
               let e = calendar.date(from: DateComponents(year: year, month: month, day: 15)) {
                periods.append(BiweeklyPeriod(startDate: s, endDate: e))
            }

            // Second half: 16–end
            if let s = calendar.date(from: DateComponents(year: year, month: month, day: 16)),
               let nextMonth = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) {
                let e = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
                periods.append(BiweeklyPeriod(startDate: s, endDate: e))
            }

            // Advance
            current = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) ?? latest.addingTimeInterval(86400)
        }

        return periods
    }

    // MARK: - Page Helpers

    static func beginPage(ctx: CGContext) {
        ctx.beginPDFPage(nil)
        // Flip to top-down
        ctx.translateBy(x: 0, y: pageH)
        ctx.scaleBy(x: 1, y: -1)
    }

    static func endPage(ctx: CGContext) {
        ctx.endPDFPage()
    }

    /// Returns the Y position after the header
    @discardableResult
    static func drawHeader(ctx: CGContext, subtitle: String, pageNumber: Int) -> CGFloat {
        var y = margin

        // Title (left-aligned)
        drawText(ctx: ctx, text: pdfTitle,
                 rect: CGRect(x: margin, y: y, width: contentW, height: 20),
                 font: titleFont, color: .black, alignment: .left)
        y += 22

        // Subtitle / date range (left-aligned)
        drawText(ctx: ctx, text: subtitle,
                 rect: CGRect(x: margin, y: y, width: contentW, height: 16),
                 font: subtitleFont, color: .darkGray, alignment: .left)
        y += 20

        // Divider line
        ctx.setStrokeColor(PlatformColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageW - margin, y: y))
        ctx.strokePath()
        y += 8

        return y
    }

    static func drawPageNumber(ctx: CGContext, pageNumber: Int) {
        let y = pageH - margin + 10
        drawText(ctx: ctx, text: "Page \(pageNumber)",
                 rect: CGRect(x: margin, y: y, width: contentW, height: 14),
                 font: smallFont, color: .gray, alignment: .center)
    }

    // MARK: - Table Drawing

    static func drawTableHeader(ctx: CGContext, y: CGFloat) -> CGFloat {
        var x = margin
        let headers = [("Date", colDate), ("Category", colCategory), ("Description", colDescription), ("Account", colAccount), ("Amount", colAmount)]

        // Background
        fillRect(ctx: ctx, rect: CGRect(x: margin, y: y, width: contentW, height: headerH), color: PlatformColor.systemGray.withAlphaComponent(0.15))

        for (title, width) in headers {
            let align: NSTextAlignment = title == "Amount" ? .right : .left
            drawText(ctx: ctx, text: title,
                     rect: CGRect(x: x + 4, y: y + 3, width: width - 8, height: headerH - 6),
                     font: headerFont, color: .black, alignment: align)
            x += width
        }

        // Bottom line
        let lineY = y + headerH
        ctx.setStrokeColor(PlatformColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: lineY))
        ctx.addLine(to: CGPoint(x: pageW - margin, y: lineY))
        ctx.strokePath()

        return y + headerH
    }

    static func drawTransactionRow(ctx: CGContext, transaction: Transaction, y: CGFloat, viewModel: LedgerViewModel) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"

        var x = margin
        let amountColor: PlatformColor = transaction.amount >= 0 ? .systemGreen : .systemRed

        let values: [(String, CGFloat, PlatformColor, NSTextAlignment)] = [
            (dateFormatter.string(from: transaction.date), colDate, .label, .left),
            (transaction.category, colCategory, .label, .left),
            (transaction.descriptionText, colDescription, .label, .left),
            (transaction.account, colAccount, .label, .left),
            (String(format: "$%.2f", abs(transaction.amount)), colAmount, amountColor, .right),
        ]

        for (text, width, color, align) in values {
            drawText(ctx: ctx, text: text,
                     rect: CGRect(x: x + 4, y: y + 2, width: width - 8, height: rowH - 4),
                     font: bodyFont, color: color, alignment: align)
            x += width
        }
    }

    // MARK: - Chart Drawing

    static func drawCategoryBarChart(
        ctx: CGContext,
        rect: CGRect,
        transactions: [Transaction],
        categoryItems: [CategoryItem],
        viewModel: LedgerViewModel,
        refundMatchedIDs: Set<UUID>
    ) {
        // Aggregate amounts by category
        var amountDict: [String: Double] = [:]
        for t in transactions {
            if t.amount < 0 && !refundMatchedIDs.contains(t.id) {
                amountDict[t.category, default: 0] += abs(t.amount)
            } else if t.amount > 0 && !refundMatchedIDs.contains(t.id) {
                amountDict[t.category, default: 0] += t.amount
            }
        }

        struct BarData {
            let label: String
            let amount: Double
            let color: PlatformColor
        }

        // Build bars in static sort order — expense first, then income
        let expenseCategories = categoryItems
            .filter { $0.type == "expense" }
            .sorted { $0.sortOrder < $1.sortOrder }
        let incomeCategories = categoryItems
            .filter { $0.type == "income" }
            .sorted { $0.sortOrder < $1.sortOrder }

        var expenseBars: [BarData] = expenseCategories.map { cat in
            BarData(label: cat.name, amount: amountDict[cat.name] ?? 0, color: PlatformColor(cat.color))
        }
        var incomeBars: [BarData] = incomeCategories.map { cat in
            BarData(label: cat.name, amount: amountDict[cat.name] ?? 0, color: PlatformColor(cat.color))
        }

        let totalSlots = expenseBars.count + incomeBars.count
        guard totalSlots > 0 else { return }

        let maxAmt = max(amountDict.values.max() ?? 1, 1)
        let labelH: CGFloat = 30
        let sectionLabelH: CGFloat = 14   // "Expense" / "Income" labels
        let amountLabelH: CGFloat = 14    // dollar amount above tallest bar
        let chartTop = rect.minY + sectionLabelH + amountLabelH  // room for both label rows
        let chartBottom = rect.maxY - labelH
        let chartH = chartBottom - chartTop

        let gapBetweenGroups: CGFloat = 16
        let spacing: CGFloat = 3
        let maxBarW: CGFloat = 30
        let totalSpacing = CGFloat(totalSlots - 1) * spacing + gapBetweenGroups
        let barW = min((rect.width - totalSpacing) / CGFloat(totalSlots), maxBarW)
        let totalW = CGFloat(totalSlots) * barW + CGFloat(totalSlots - 1) * spacing + gapBetweenGroups
        let startX = rect.minX + (rect.width - totalW) / 2

        var currentX = startX

        // Draw expense bars
        for bar in expenseBars {
            drawSingleBar(ctx: ctx, label: bar.label, amount: bar.amount, color: bar.color, x: currentX, barW: barW, chartTop: chartTop, chartBottom: chartBottom, chartH: chartH, maxAmt: maxAmt, labelH: labelH)
            currentX += barW + spacing
        }

        // Gap between expense and income
        currentX += gapBetweenGroups - spacing

        // Draw a thin separator line in the gap
        let sepX = currentX - gapBetweenGroups / 2
        ctx.setStrokeColor(PlatformColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: sepX, y: chartTop - 4))
        ctx.addLine(to: CGPoint(x: sepX, y: chartBottom + 4))
        ctx.strokePath()

        // Draw "Expense" / "Income" section labels (above the amount labels)
        let expenseLabelX = startX
        let expenseLabelW = CGFloat(expenseBars.count) * (barW + spacing) - spacing
        drawText(ctx: ctx, text: "Expense",
                 rect: CGRect(x: expenseLabelX, y: rect.minY, width: expenseLabelW, height: 12),
                 font: PlatformFont.boldSystemFont(ofSize: 7), color: .systemRed, alignment: .center)

        let incomeLabelX = currentX
        let incomeLabelW = CGFloat(incomeBars.count) * (barW + spacing) - spacing
        drawText(ctx: ctx, text: "Income",
                 rect: CGRect(x: incomeLabelX, y: rect.minY, width: incomeLabelW, height: 12),
                 font: PlatformFont.boldSystemFont(ofSize: 7), color: .systemGreen, alignment: .center)

        // Draw income bars
        for bar in incomeBars {
            drawSingleBar(ctx: ctx, label: bar.label, amount: bar.amount, color: bar.color, x: currentX, barW: barW, chartTop: chartTop, chartBottom: chartBottom, chartH: chartH, maxAmt: maxAmt, labelH: labelH)
            currentX += barW + spacing
        }
    }

    private static func drawSingleBar(
        ctx: CGContext,
        label: String, amount: Double, color: PlatformColor,
        x: CGFloat, barW: CGFloat,
        chartTop: CGFloat, chartBottom: CGFloat, chartH: CGFloat,
        maxAmt: Double, labelH: CGFloat
    ) {
        let barH = amount > 0 ? chartH * CGFloat(amount / maxAmt) : 0
        let barY = chartBottom - barH

        if barH > 0 {
            fillRect(ctx: ctx, rect: CGRect(x: x, y: barY, width: barW, height: barH), color: color)
        }

        // Label below
        let labelRect = CGRect(x: x - 2, y: chartBottom + 2, width: barW + 4, height: labelH - 4)
        drawText(ctx: ctx, text: label, rect: labelRect, font: PlatformFont.systemFont(ofSize: 6), color: .darkGray, alignment: .center)

        // Amount on top (only if > 0)
        if amount > 0 {
            let amtRect = CGRect(x: x - 10, y: barY - 12, width: barW + 20, height: 12)
            drawText(ctx: ctx, text: String(format: "$%.0f", amount), rect: amtRect, font: PlatformFont.systemFont(ofSize: 6), color: .darkGray, alignment: .center)
        }
    }

    // MARK: - Drawing Primitives

    static func drawText(ctx: CGContext, text: String, rect: CGRect, font: PlatformFont, color: PlatformColor, alignment: NSTextAlignment = .left) {
        #if canImport(AppKit)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        #elseif canImport(UIKit)
        UIGraphicsPushContext(ctx)
        #endif

        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
        ]

        (text as NSString).draw(in: rect, withAttributes: attrs)

        #if canImport(AppKit)
        NSGraphicsContext.restoreGraphicsState()
        #elseif canImport(UIKit)
        UIGraphicsPopContext()
        #endif
    }

    static func fillRect(ctx: CGContext, rect: CGRect, color: PlatformColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }
}
