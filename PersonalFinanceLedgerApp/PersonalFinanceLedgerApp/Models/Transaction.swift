import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var descriptionText: String
    var category: String
    var amount: Double
    var account: String

    init(id: UUID = UUID(), date: Date = .now, descriptionText: String = "", category: String = "", amount: Double = 0, account: String = "Chase") {
        self.id = id
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
