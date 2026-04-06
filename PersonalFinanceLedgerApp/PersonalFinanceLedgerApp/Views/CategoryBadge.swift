import SwiftUI

struct CategoryBadge: View {
    let category: String
    var categoryItems: [CategoryItem] = []

    private var resolvedColor: Color {
        categoryItems.first(where: { $0.name == category })?.color
            ?? CategoryInfo.color(for: category)
    }

    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(resolvedColor.opacity(0.15))
            .foregroundStyle(resolvedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(resolvedColor.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
