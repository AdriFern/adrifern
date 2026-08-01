import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var routines: [Routine]
    @Query private var contexts: [ContextTag]

    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay: SelectedDay?

    /// Small wrapper instead of a retroactive Identifiable conformance on Date.
    struct SelectedDay: Identifiable {
        let day: Date
        var id: Date { day }
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    legend
                }
                .padding(.horizontal)
            }
            .navigationTitle(String(localized: "Calendar"))
            .toolbar {
                Button(String(localized: "Today")) {
                    displayedMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
                }
                .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
            }
            .sheet(item: $selectedDay) { selected in
                NavigationStack {
                    DayChecklistView(day: selected.day)
                        .navigationTitle(selected.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(Text(String(localized: "Previous month")))
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(Text(String(localized: "Next month")))
        }
        .padding(.top, 8)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var monthGrid: some View {
        // One pass per month, not per cell: occurrences, colors, and active
        // contexts are precomputed for the whole grid.
        let days = daysInDisplayedMonth()
        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let patterned = contexts.filter { $0.pattern.kind != .always }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    let occurrences = Scheduler.occurrences(for: routines, contexts: contexts, on: day)
                    let dotColors = occurrences.prefix(4).compactMap { routineMap[$0.routineID]?.colorName }
                    let active = patterned.filter { Scheduler.isContextActive($0.pattern, on: day) }
                    DayCell(day: day, dotColors: dotColors, activeContexts: active)
                        .onTapGesture { selectedDay = SelectedDay(day: day) }
                        .accessibilityElement()
                        .accessibilityLabel(Text(dayAccessibilityLabel(day: day, count: occurrences.count, active: active)))
                        .accessibilityAddTraits(.isButton)
                } else {
                    Color.clear.frame(height: 54)
                }
            }
        }
    }

    private func dayAccessibilityLabel(day: Date, count: Int, active: [ContextTag]) -> String {
        var parts = [day.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        parts.append(String(localized: "\(count) routine(s)"))
        for context in active {
            parts.append(String(localized: "\(context.name) with you"))
        }
        return parts.joined(separator: ", ")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            let patterned = contexts.filter { $0.pattern.kind != .always }
            if !patterned.isEmpty {
                Text(String(localized: "Background tint = who's with you that day"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    ForEach(patterned) { context in
                        ContextChip(context: context)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func moveMonth(_ value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    /// Days of the displayed month padded with nils so the grid starts on the calendar's first weekday.
    private func daysInDisplayedMonth() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = ((firstWeekday - calendar.firstWeekday) + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in dayRange {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return days
    }
}

private struct DayCell: View {
    let day: Date
    let dotColors: [String]
    let activeContexts: [ContextTag]

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            HStack(spacing: 3) {
                ForEach(Array(dotColors.enumerated()), id: \.offset) { _, colorName in
                    Circle()
                        .fill(Palette.color(colorName))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
            // Tiny symbol per active context so meaning isn't color-only.
            HStack(spacing: 2) {
                ForEach(activeContexts.prefix(2)) { context in
                    Image(systemName: context.symbol)
                        .font(.system(size: 7))
                        .foregroundStyle(Palette.color(context.colorName))
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(backgroundTint, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
    }

    private var backgroundTint: Color {
        if let context = activeContexts.first {
            return Palette.color(context.colorName).opacity(0.14)
        }
        return Color(.systemGray6)
    }
}
