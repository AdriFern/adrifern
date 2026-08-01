import Foundation

// MARK: - Recurrence

enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case daily
    case everyNDays
    case weekly
    case monthly
    case once

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return String(localized: "Every day")
        case .everyNDays: return String(localized: "Every few days")
        case .weekly: return String(localized: "Days of the week")
        case .monthly: return String(localized: "Days of the month")
        case .once: return String(localized: "One time")
        }
    }

    var symbol: String {
        switch self {
        case .daily: return "sun.max"
        case .everyNDays: return "arrow.triangle.2.circlepath"
        case .weekly: return "calendar.day.timeline.left"
        case .monthly: return "calendar"
        case .once: return "1.circle"
        }
    }
}

/// Stored inside Routine as versioned JSON. Decoding uses `decodeIfPresent`
/// with defaults for EVERY field so adding fields in future versions can never
/// invalidate existing user data — a hard requirement for a shipping app.
struct Schedule: Codable, Equatable {
    var version: Int = 1
    var kind: ScheduleKind = .daily
    /// Interval for `.everyNDays` (2 = every other day). Counted from `startDate`.
    var interval: Int = 2
    /// Weekdays for `.weekly` (1 = Sunday … 7 = Saturday, matching `Calendar`).
    var weekdays: Set<Int> = []
    /// Days of the month for `.monthly` (1…31). Days beyond a month's length
    /// clamp to its last day (31 → Feb 28/29), industry-standard behavior.
    var monthDays: Set<Int> = []
    var startDate: Date = Calendar.current.startOfDay(for: .now)
    var endDate: Date?

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, kind, interval, weekdays, monthDays, startDate, endDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        kind = (try? c.decodeIfPresent(ScheduleKind.self, forKey: .kind)) ?? .daily
        interval = (try? c.decodeIfPresent(Int.self, forKey: .interval)) ?? 2
        weekdays = (try? c.decodeIfPresent(Set<Int>.self, forKey: .weekdays)) ?? []
        monthDays = (try? c.decodeIfPresent(Set<Int>.self, forKey: .monthDays)) ?? []
        startDate = (try? c.decodeIfPresent(Date.self, forKey: .startDate)) ?? Calendar.current.startOfDay(for: .now)
        endDate = try? c.decodeIfPresent(Date.self, forKey: .endDate)
    }

    func summary(times: [Int]) -> String {
        let timeText = times.isEmpty ? "" : " " + String(localized: "at") + " " + times.sorted().map { $0.timeString }.joined(separator: ", ")
        return recurrenceText + timeText
    }

    var recurrenceText: String {
        switch kind {
        case .daily:
            return String(localized: "Every day")
        case .everyNDays:
            return interval == 2
                ? String(localized: "Every other day")
                : String(localized: "Every \(interval) days")
        case .weekly:
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().map { symbols[$0 - 1] }
            return names.isEmpty ? String(localized: "Weekly") : names.joined(separator: ", ")
        case .monthly:
            let days = monthDays.sorted().map(String.init)
            return days.isEmpty
                ? String(localized: "Monthly")
                : String(localized: "Monthly on day \(days.joined(separator: ", "))")
        case .once:
            return String(localized: "Once on \(startDate.formatted(date: .abbreviated, time: .omitted))")
        }
    }
}

// MARK: - Context presence (custody-style week patterns)

enum PresenceKind: String, Codable, CaseIterable, Identifiable {
    case always
    case alternatingWeeks
    case weekdays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always: return String(localized: "Always with me")
        case .alternatingWeeks: return String(localized: "Alternating weeks")
        case .weekdays: return String(localized: "Certain days each week")
        }
    }
}

/// Stored inside ContextTag as versioned JSON — same forward-compatible
/// decoding rules as Schedule.
struct PresencePattern: Codable, Equatable {
    var version: Int = 1
    var kind: PresenceKind = .alternatingWeeks
    /// Any date that falls inside an "on" week for `.alternatingWeeks`.
    var anchorDate: Date = Calendar.current.startOfDay(for: .now)
    var weeksOn: Int = 1
    var weeksOff: Int = 1
    /// Weekdays for `.weekdays` (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int> = []
    /// The weekday the rotation switches on (1 = Sunday … 7 = Saturday).
    /// Real custody handoffs are rarely at the calendar week boundary; storing
    /// it explicitly also keeps the boundary stable across locale changes.
    var handoffWeekday: Int = Calendar.current.firstWeekday

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, kind, anchorDate, weeksOn, weeksOff, weekdays, handoffWeekday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        kind = (try? c.decodeIfPresent(PresenceKind.self, forKey: .kind)) ?? .alternatingWeeks
        anchorDate = (try? c.decodeIfPresent(Date.self, forKey: .anchorDate)) ?? Calendar.current.startOfDay(for: .now)
        weeksOn = (try? c.decodeIfPresent(Int.self, forKey: .weeksOn)) ?? 1
        weeksOff = (try? c.decodeIfPresent(Int.self, forKey: .weeksOff)) ?? 1
        weekdays = (try? c.decodeIfPresent(Set<Int>.self, forKey: .weekdays)) ?? []
        handoffWeekday = (try? c.decodeIfPresent(Int.self, forKey: .handoffWeekday)) ?? Calendar.current.firstWeekday
    }

    var summary: String {
        switch kind {
        case .always:
            return String(localized: "Always")
        case .alternatingWeeks:
            if weeksOn == 1 && weeksOff == 1 { return String(localized: "Every other week") }
            return String(localized: "\(weeksOn) weeks with you, \(weeksOff) away")
        case .weekdays:
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().map { symbols[$0 - 1] }
            return names.isEmpty ? String(localized: "Certain days") : names.joined(separator: ", ")
        }
    }
}

// MARK: - Alerts

enum AlertMode: String, Codable, CaseIterable, Identifiable {
    case none
    case notification
    case alarm

    var id: String { rawValue }

    /// Honest labels: alarm mode re-alerts a configurable number of times —
    /// it is not an unlimited alarm and never overrides the silent switch.
    var label: String {
        switch self {
        case .none: return String(localized: "Silent (checklist only)")
        case .notification: return String(localized: "Notification")
        case .alarm: return String(localized: "Alarm (repeat alerts)")
        }
    }

    var symbol: String {
        switch self {
        case .none: return "bell.slash"
        case .notification: return "bell"
        case .alarm: return "alarm"
        }
    }
}

// MARK: - Small helpers

extension Int {
    /// Treats the value as minutes from midnight and renders "8:30 AM".
    var timeString: String {
        var comps = DateComponents()
        comps.hour = self / 60
        comps.minute = self % 60
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension Date {
    var minutesFromMidnight: Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
