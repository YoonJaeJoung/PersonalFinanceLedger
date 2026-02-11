import Foundation
import SwiftData

@Model
final class Transaction {
    var date: Date
    var descriptionText: String
    var category: String
    var amount: Double
    var account: String

    init(date: Date = .now, descriptionText: String = "", category: String = "", amount: Double = 0, account: String = "Chase") {
        self.date = date
        self.descriptionText = descriptionText
        self.category = category
        self.amount = amount
        self.account = account
    }

    var isIncome: Bool { amount >= 0 }

    var displayAmount: String {
        String(format: "$%.2f", abs(amount))
    }
}
