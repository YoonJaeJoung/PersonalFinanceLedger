import Foundation
import SwiftData

@Model
final class AccountItem {
    var name: String
    var csvFileName: String
    var sortOrder: Int

    init(name: String, csvFileName: String = "", sortOrder: Int = 0) {
        self.name = name
        self.csvFileName = csvFileName
        self.sortOrder = sortOrder
    }
}
