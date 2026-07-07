import SwiftUI

// MARK: - Hex colors

extension Color {
    /// Creates a color from a "#RRGGBB" hex string.
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

// MARK: - App theme

enum Theme {
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20

    static var background: Color { Color(.systemGroupedBackground) }
    static var cardBackground: Color { Color(.secondarySystemGroupedBackground) }

    /// Soft fill used for calendar day cells.
    static func dayFill(_ base: Color, scheme: ColorScheme) -> Color {
        base.opacity(scheme == .dark ? 0.38 : 0.22)
    }
}

// MARK: - Reusable components

/// Small colored dot used to identify a parent.
struct ParentDot: View {
    var colorHex: String
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
    }
}

/// Big rounded primary action button.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary bordered button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Horizontal color swatch picker.
struct ColorSwatchPicker: View {
    @Binding var selection: String
    var disabledHex: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Palette.options, id: \.self) { hex in
                    let isDisabled = hex == disabledHex
                    Button {
                        selection = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 38, height: 38)
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                            if isDisabled {
                                Circle()
                                    .fill(.black.opacity(0.45))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .disabled(isDisabled)
                    .accessibilityLabel(Text(Palette.name(for: hex)))
                    .accessibilityAddTraits(selection == hex ? [.isSelected] : [])
                    .accessibilityHint(isDisabled ? Text("Already used by your co-parent") : Text(""))
                }
            }
            .padding(.vertical, 4)
        }
    }
}
