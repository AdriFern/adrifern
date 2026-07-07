import Foundation

/// Calendar day helpers. Days are identified everywhere by a stable
/// "yyyy-MM-dd" key in the device's local calendar.
enum Day {
    static var calendar: Calendar { Calendar.current }

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        keyFormatter.date(from: key)
    }

    static var todayKey: String { key(for: Date()) }

    static func keys(from start: Date, to end: Date) -> [String] {
        var result: [String] = []
        var current = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while current <= last {
            result.append(key(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// Short human date like "Tue, Jul 8" / "mar, 8 jul".
    static func shortLabel(for key: String) -> String {
        guard let date = date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Full human date like "Tuesday, July 8, 2026".
    static func longLabel(for key: String) -> String {
        guard let date = date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }
}

// MARK: - Month grid

/// One month of the calendar, laid out as a 7-column grid.
struct Month: Identifiable, Equatable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }

    static func containing(_ date: Date) -> Month {
        let components = Day.calendar.dateComponents([.year, .month], from: date)
        return Month(year: components.year ?? 2000, month: components.month ?? 1)
    }

    var firstDate: Date {
        Day.calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var title: String {
        firstDate.formatted(.dateTime.month(.wide).year())
    }

    func adding(_ delta: Int) -> Month {
        let date = Day.calendar.date(byAdding: .month, value: delta, to: firstDate) ?? firstDate
        return Month.containing(date)
    }

    /// Days of this month as date keys, in order.
    var dayKeys: [String] {
        guard let range = Day.calendar.range(of: .day, in: .month, for: firstDate) else { return [] }
        return range.compactMap { day -> String? in
            guard let date = Day.calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
            return Day.key(for: date)
        }
    }

    /// Number of empty leading cells so day 1 lands on the right weekday column,
    /// honoring the locale's first day of the week.
    var leadingBlanks: Int {
        let weekdayOfFirst = Day.calendar.component(.weekday, from: firstDate)
        return (weekdayOfFirst - Day.calendar.firstWeekday + 7) % 7
    }

    /// Localized weekday symbols starting on the locale's first weekday.
    static var weekdaySymbols: [String] {
        let symbols = Day.calendar.veryShortStandaloneWeekdaySymbols
        let first = Day.calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}
