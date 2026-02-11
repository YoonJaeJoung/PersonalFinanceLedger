import Foundation
import SwiftData

struct CSVImporter {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Import a single CSV file into SwiftData. Returns number of rows imported.
    static func importCSV(from url: URL, account: String, context: ModelContext) throws -> Int {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return 0 }

        var count = 0
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let fields = parseCSVLine(trimmed)
            guard fields.count >= 4 else { continue }

            let dateStr = fields[0].trimmingCharacters(in: .whitespaces)
            let desc = fields[1].trimmingCharacters(in: .whitespaces)
            let cat = fields[2].trimmingCharacters(in: .whitespaces)
            let amtStr = fields[3].trimmingCharacters(in: .whitespaces)

            guard let date = dateFormatter.date(from: dateStr),
                  let amount = Double(amtStr) else { continue }

            let transaction = Transaction(
                date: date,
                descriptionText: desc,
                category: cat,
                amount: amount,
                account: account
            )
            context.insert(transaction)
            count += 1
        }
        try context.save()
        return count
    }

    /// Import all known CSV files from a directory.
    static func importAllCSVs(from directoryURL: URL, context: ModelContext) throws -> Int {
        var total = 0
        for (account, filename) in CategoryInfo.accountFileMapping {
            let fileURL = directoryURL.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let count = try importCSV(from: fileURL, account: account, context: context)
            total += count
        }
        return total
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }

    /// Export transactions for one account back to CSV format.
    static func exportCSV(transactions: [Transaction], account: String) -> String {
        var csv = "Date,Description,Category,Amount\n"
        let filtered = transactions
            .filter { $0.account == account }
            .sorted { $0.date < $1.date }
        for t in filtered {
            let dateStr = dateFormatter.string(from: t.date)
            let desc = t.descriptionText.contains(",") ? "\"\(t.descriptionText)\"" : t.descriptionText
            csv += "\(dateStr),\(desc),\(t.category),\(String(format: "%.2f", t.amount))\n"
        }
        return csv
    }
}
