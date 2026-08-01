import SwiftUI

// MARK: - Palette

enum Palette {
    static let colorNames = ["red", "orange", "yellow", "green", "mint", "teal", "cyan", "blue", "indigo", "purple", "pink", "brown"]

    static func color(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        default: return .blue
        }
    }

    static func localizedName(_ name: String) -> String {
        switch name {
        case "red": return String(localized: "Red")
        case "orange": return String(localized: "Orange")
        case "yellow": return String(localized: "Yellow")
        case "green": return String(localized: "Green")
        case "mint": return String(localized: "Mint")
        case "teal": return String(localized: "Teal")
        case "cyan": return String(localized: "Cyan")
        case "blue": return String(localized: "Blue")
        case "indigo": return String(localized: "Indigo")
        case "purple": return String(localized: "Purple")
        case "pink": return String(localized: "Pink")
        case "brown": return String(localized: "Brown")
        default: return name
        }
    }
}

enum SymbolChoices {
    static let routine = ["pills", "pills.fill", "cross.case", "heart.fill", "book.fill", "pencil.and.ruler",
                          "backpack.fill", "graduationcap.fill", "soccerball", "figure.run", "pawprint.fill",
                          "dog.fill", "cat.fill", "fish.fill", "fork.knife", "drop.fill", "sparkles",
                          "face.smiling", "shower.fill", "bed.double.fill", "briefcase.fill", "laptopcomputer",
                          "phone.fill", "envelope.fill", "cart.fill", "creditcard.fill", "house.fill",
                          "leaf.fill", "trash.fill", "car.fill", "alarm.fill", "star.fill", "checklist"]
    static let context = ["person.fill", "figure.child", "figure.2.and.child.holdinghands", "pawprint.fill",
                          "dog.fill", "cat.fill", "bird.fill", "fish.fill", "person.2.fill", "heart.fill",
                          "house.fill", "star.fill"]
}

// MARK: - Reusable pickers

struct SymbolColorPicker: View {
    @Binding var symbol: String
    @Binding var colorName: String
    var symbols: [String]

    @ScaledMetric(relativeTo: .title3) private var swatchSize: CGFloat = 34
    @ScaledMetric(relativeTo: .title3) private var tileSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Palette.color(colorName).gradient, in: Circle())
                    .accessibilityLabel(Text(String(localized: "Selected icon with \(Palette.localizedName(colorName)) color")))
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(Palette.colorNames, id: \.self) { name in
                    Button {
                        colorName = name
                    } label: {
                        Circle()
                            .fill(Palette.color(name).gradient)
                            .frame(width: swatchSize, height: swatchSize)
                            .overlay {
                                if name == colorName {
                                    Circle().strokeBorder(.primary, lineWidth: 2).padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Palette.localizedName(name)))
                    .accessibilityAddTraits(name == colorName ? [.isSelected] : [])
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(symbols, id: \.self) { name in
                    Button {
                        symbol = name
                    } label: {
                        Image(systemName: name)
                            .font(.title3)
                            .frame(width: tileSize, height: tileSize)
                            .background(symbol == name ? Palette.color(colorName).opacity(0.25) : Color(.systemGray6),
                                        in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(name.replacingOccurrences(of: ".", with: " ")))
                    .accessibilityAddTraits(symbol == name ? [.isSelected] : [])
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    @ScaledMetric(relativeTo: .subheadline) private var circleSize: CGFloat = 38

    // Weekdays presented in the user's locale order (Monday-first in most of
    // Europe, Sunday-first in the US), matching the calendar tab.
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    var body: some View {
        let shortSymbols = Calendar.current.veryShortWeekdaySymbols
        let fullSymbols = Calendar.current.weekdaySymbols
        HStack(spacing: 8) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let selected = selection.contains(weekday)
                Button {
                    if selected { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(shortSymbols[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: circleSize, height: circleSize)
                        .background(selected ? Color.accentColor : Color(.systemGray5), in: Circle())
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(fullSymbols[weekday - 1]))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthDayPicker: View {
    @Binding var selection: Set<Int>

    @ScaledMetric(relativeTo: .subheadline) private var circleSize: CGFloat = 36

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                let selected = selection.contains(day)
                Button {
                    if selected { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text("\(day)")
                        .font(.subheadline)
                        .frame(width: circleSize, height: circleSize)
                        .background(selected ? Color.accentColor : Color(.systemGray6), in: Circle())
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Day \(day)")))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Small views

struct ContextChip: View {
    let context: ContextTag

    var body: some View {
        Label(context.name, systemImage: context.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.color(context.colorName).opacity(0.18), in: Capsule())
            .foregroundStyle(Palette.color(context.colorName))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}
