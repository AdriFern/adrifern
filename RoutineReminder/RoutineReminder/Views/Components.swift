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
}

enum SymbolChoices {
    static let routine = ["pills", "pills.fill", "cross.case", "heart.fill", "book.fill", "pencil.and.ruler",
                          "backpack.fill", "graduationcap.fill", "soccerball", "figure.run", "pawprint.fill",
                          "dog.fill", "cat.fill", "fish.fill", "fork.knife", "drop.fill", "sparkles",
                          "face.smiling", "shower.fill", "bed.double.fill", "briefcase.fill", "laptopcomputer",
                          "phone.fill", "envelope.fill", "cart.fill", "creditcard.fill", "house.fill",
                          "leaf.fill", "trash.fill", "car.fill", "alarm.fill", "star.fill"]
    static let context = ["person.fill", "figure.child", "figure.2.and.child.holdinghands", "pawprint.fill",
                          "dog.fill", "cat.fill", "bird.fill", "fish.fill", "person.2.fill", "heart.fill",
                          "house.fill", "star.fill"]
}

// MARK: - Reusable pickers

struct SymbolColorPicker: View {
    @Binding var symbol: String
    @Binding var colorName: String
    var symbols: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Palette.color(colorName).gradient, in: Circle())
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(Palette.colorNames, id: \.self) { name in
                    Circle()
                        .fill(Palette.color(name).gradient)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if name == colorName {
                                Circle().strokeBorder(.primary, lineWidth: 2).padding(-4)
                            }
                        }
                        .onTapGesture { colorName = name }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(symbols, id: \.self) { name in
                    Image(systemName: name)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(symbol == name ? Palette.color(colorName).opacity(0.25) : Color(.systemGray6),
                                    in: RoundedRectangle(cornerRadius: 9))
                        .onTapGesture { symbol = name }
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private let symbols = Calendar.current.veryShortWeekdaySymbols // index 0 = Sunday

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = selection.contains(weekday)
                Text(symbols[weekday - 1])
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(selected ? Color.accentColor : Color(.systemGray5), in: Circle())
                    .foregroundStyle(selected ? .white : .primary)
                    .onTapGesture {
                        if selected { selection.remove(weekday) } else { selection.insert(weekday) }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthDayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                let selected = selection.contains(day)
                Text("\(day)")
                    .font(.subheadline)
                    .frame(width: 36, height: 36)
                    .background(selected ? Color.accentColor : Color(.systemGray6), in: Circle())
                    .foregroundStyle(selected ? .white : .primary)
                    .onTapGesture {
                        if selected { selection.remove(day) } else { selection.insert(day) }
                    }
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
