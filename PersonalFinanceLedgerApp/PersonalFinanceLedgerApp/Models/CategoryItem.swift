import Foundation
import SwiftUI
import SwiftData

@Model
final class CategoryItem {
    var name: String
    var type: String          // "expense" or "income"
    var colorHex: String      // e.g. "#EF4444"
    var sortOrder: Int

    init(name: String, type: String, colorHex: String, sortOrder: Int = 0) {
        self.name = name
        self.type = type
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var isExpense: Bool { type == "expense" }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let int = UInt64(hex, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        let components = NSColor(self).usingColorSpace(.sRGB)
        let r = Int((components?.redComponent ?? 0) * 255)
        let g = Int((components?.greenComponent ?? 0) * 255)
        let b = Int((components?.blueComponent ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
