import SwiftUI

/// Horizontal scrollable palette of element categories.
struct ElementPaletteView: View {
    let mode: ViewMode
    let onSelect: (ElementCategory) -> Void

    private var categories: [ElementCategory] {
        ElementCategory.allCases.filter { $0.isRoofElement == (mode == .roof) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Elements  –  tap to configure & add")
                .font(.system(size: 11))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(categories) { category in
                        PaletteItemView(category: category)
                            .onTapGesture { onSelect(category) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Text("Drag placed elements to reposition  •  tap to select  •  tap again to edit")
                .font(.system(size: 10))
                .foregroundColor(Color(.systemGray3))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
    }
}

// MARK: - Palette Item

struct PaletteItemView: View {
    let category: ElementCategory

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(category.color.opacity(0.14))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(category.color.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: category.icon)
                    .font(.system(size: 26))
                    .foregroundColor(category.color)
            }

            Text(category.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 68)
        }
        .contentShape(Rectangle())
    }
}
