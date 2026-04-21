import Foundation
import SwiftUI

struct CategoryItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var type: String          // "expense" or "income"
    var colorHex: String      // e.g. "#EF4444"
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, type: String, colorHex: String, sortOrder: Int = 0) {
        self.id = id
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

    #if canImport(AppKit)
    func toHex() -> String {
        let components = NSColor(self).usingColorSpace(.sRGB)
        let r = Int((components?.redComponent ?? 0) * 255)
        let g = Int((components?.greenComponent ?? 0) * 255)
        let b = Int((components?.blueComponent ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    #elseif canImport(UIKit)
    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    #endif
}
