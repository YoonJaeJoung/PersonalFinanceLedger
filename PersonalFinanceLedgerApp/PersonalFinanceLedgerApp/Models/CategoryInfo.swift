import SwiftUI

struct CategoryInfo {
    static let expenseCategories = [
        "Groceries", "Food", "Restaurant Week", "NBA", "Broadway",
        "Transportation", "Medical", "Home", "Etc"
    ]
    static let incomeCategories = [
        "Allowance", "Gift", "Boucher", "Refund", "Etc"
    ]
    static let allCategories: [String] = {
        var set = Set(expenseCategories)
        set.formUnion(incomeCategories)
        return Array(set).sorted()
    }()

    static let accounts = ["Chase", "Cash", "Toss", "Travellog"]

    static let accountFileMapping: [String: String] = [
        "Chase": "chase.csv",
        "Cash": "cash.csv",
        "Toss": "toss.csv",
        "Travellog": "travellog.csv"
    ]

    static let categoryColors: [String: Color] = [
        "Groceries": Color(red: 0.937, green: 0.267, blue: 0.267),
        "Food": Color(red: 0.984, green: 0.573, blue: 0.235),
        "Restaurant Week": Color(red: 0.961, green: 0.620, blue: 0.043),
        "NBA": Color(red: 0.063, green: 0.725, blue: 0.506),
        "Broadway": Color(red: 0.659, green: 0.333, blue: 0.969),
        "Transportation": Color(red: 0.231, green: 0.510, blue: 0.965),
        "Medical": Color(red: 0.925, green: 0.282, blue: 0.600),
        "Home": Color(red: 0.420, green: 0.447, blue: 0.502),
        "Etc": Color(red: 0.580, green: 0.639, blue: 0.722),
        "Allowance": Color(red: 0.133, green: 0.773, blue: 0.369),
        "Gift": Color(red: 0.220, green: 0.741, blue: 0.973),
        "Boucher": Color(red: 0.753, green: 0.518, blue: 0.988),
        "Refund": Color(red: 0.204, green: 0.827, blue: 0.600),
    ]

    static func color(for category: String) -> Color {
        categoryColors[category] ?? .gray
    }
}
