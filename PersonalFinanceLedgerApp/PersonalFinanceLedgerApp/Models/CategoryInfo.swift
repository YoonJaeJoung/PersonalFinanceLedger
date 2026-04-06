import SwiftUI
import SwiftData

struct CategoryInfo {
    // Default seed data (used on first launch only)
    static let defaultExpenseCategories: [(name: String, hex: String)] = [
        ("Groceries",       "#EF4444"), // 0
        ("Food",            "#FB9238"), // 1
        ("Restaurant Week", "#F59E0B"), // 2
        ("Cultural",        "#FFD600"), // 3
        ("NBA",             "#16792E"), // 4
        ("Sports",          "#30D158"), // 5
        ("Transportation",  "#3B82F6"), // 6
        ("Broadway",        "#A855F7"), // 7
        ("Medical",         "#EC4899"), // 8
        ("Shopping",        "#FF99CC"), // 9
        ("Home",            "#FFFFFF"), // 10
        ("Etc",             "#94A3B8"), // 11
    ]

    static let defaultIncomeCategories: [(name: String, hex: String)] = [
        ("Allowance",        "#FF4245"), // 0
        ("Gift",             "#FF9230"), // 1
        ("Boucher",          "#0091FF"), // 2
        ("Refund",           "#34D399"), // 3
        ("Currency Exchange","#FFFFFF"), // 4
        ("Etc",              "#94A3B8"), // 5
    ]

    static let defaultAccounts: [(name: String, csv: String)] = [
        ("Chase",      "chase.csv"),
        ("Cash",       "cash.csv"),
        ("Toss",       "toss.csv"),
        ("Travellog",  "travellog.csv"),
        ("Hyundai",    "hyundai.csv"),
    ]

    // MARK: - Legacy static accessors (kept for backward compatibility during transition)

    static let expenseCategories = defaultExpenseCategories.map(\.name)
    static let incomeCategories  = defaultIncomeCategories.map(\.name)

    static let allCategories: [String] = {
        var set = Set(expenseCategories)
        set.formUnion(incomeCategories)
        return Array(set).sorted()
    }()

    static let accounts = defaultAccounts.map(\.name)

    static let accountFileMapping: [String: String] = {
        Dictionary(uniqueKeysWithValues: defaultAccounts.map { ($0.name, $0.csv) })
    }()

    static let categoryColors: [String: Color] = {
        var dict: [String: Color] = [:]
        for cat in defaultExpenseCategories + defaultIncomeCategories {
            if let c = Color(hex: cat.hex) { dict[cat.name] = c }
        }
        return dict
    }()

    static func color(for category: String) -> Color {
        categoryColors[category] ?? .gray
    }

    // MARK: - Seeding & Migration

    /// Seed default categories and accounts into SwiftData if none exist.
    /// Also migrates "shopping" → "Shopping" in existing transactions.
    static func seedDefaultsIfNeeded(context: ModelContext) {
        // Seed categories
        // All saves are wrapped in do/catch to avoid crashing if the store is temporarily unavailable
        do {
            let catDescriptor = FetchDescriptor<CategoryItem>()
            let existingCats = try context.fetchCount(catDescriptor)
            if existingCats == 0 {
                for (i, cat) in defaultExpenseCategories.enumerated() {
                    context.insert(CategoryItem(name: cat.name, type: "expense", colorHex: cat.hex, sortOrder: i))
                }
                for (i, cat) in defaultIncomeCategories.enumerated() {
                    context.insert(CategoryItem(name: cat.name, type: "income", colorHex: cat.hex, sortOrder: i))
                }
                try context.save()
            }
        } catch {
            print("⚠️ Failed to seed categories: \(error)")
        }

        // Seed accounts
        do {
            let acctDescriptor = FetchDescriptor<AccountItem>()
            let existingAccts = try context.fetchCount(acctDescriptor)
            if existingAccts == 0 {
                for (i, acct) in defaultAccounts.enumerated() {
                    context.insert(AccountItem(name: acct.name, csvFileName: acct.csv, sortOrder: i))
                }
                try context.save()
            }
        } catch {
            print("⚠️ Failed to seed accounts: \(error)")
        }

        // Migrate "shopping" → "Shopping"
        do {
            let txDescriptor = FetchDescriptor<Transaction>()
            let all = try context.fetch(txDescriptor)
            var changed = false
            for t in all {
                if t.category.lowercased() == "shopping" && t.category != "Shopping" {
                    t.category = "Shopping"
                    changed = true
                }
            }
            if changed { try context.save() }
        } catch {
            print("⚠️ Failed to migrate shopping category: \(error)")
        }
    }
}

