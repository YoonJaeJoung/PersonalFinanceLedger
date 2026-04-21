import Foundation

struct AccountItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var csvFileName: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, csvFileName: String = "", sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.csvFileName = csvFileName
        self.sortOrder = sortOrder
    }
}
