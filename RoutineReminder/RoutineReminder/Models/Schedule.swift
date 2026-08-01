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
        case .daily: return "Every day"
        case .everyNDays: return "Every few days"
        case .weekly: return "Days of the week"
        case .monthly: return "Days of the month"
        case .once: return "One time"
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

struct Schedule: Codable, Equatable {
    var kind: ScheduleKind = .daily
    /// Interval for `.everyNDays` (2 = every other day). Counted from `startDate`.
    var interval: Int = 2
    /// Weekdays for `.weekly` (1 = Sunday … 7 = Saturday, matching `Calendar`).
    var weekdays: Set<Int> = []
    /// Days of the month for `.monthly` (1…31).
    var monthDays: Set<Int> = []
    var startDate: Date = Calendar.current.startOfDay(for: .now)
    var endDate: Date?

    func summary(times: [Int]) -> String {
        let timeText = times.isEmpty ? "" : " at " + times.sorted().map { $0.timeString }.joined(separator: ", ")
        return recurrenceText + timeText
    }

    var recurrenceText: String {
        switch kind {
        case .daily:
            return "Every day"
        case .everyNDays:
            return interval == 2 ? "Every other day" : "Every \(interval) days"
        case .weekly:
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().map { symbols[$0 - 1] }
            return names.isEmpty ? "Weekly" : names.joined(separator: ", ")
        case .monthly:
            let days = monthDays.sorted().map(String.init)
            return days.isEmpty ? "Monthly" : "Monthly on day " + days.joined(separator: ", ")
        case .once:
            return "Once on " + startDate.formatted(date: .abbreviated, time: .omitted)
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
        case .always: return "Always with me"
        case .alternatingWeeks: return "Alternating weeks"
        case .weekdays: return "Certain days each week"
        }
    }
}

struct PresencePattern: Codable, Equatable {
    var kind: PresenceKind = .alternatingWeeks
    /// Any date that falls inside an "on" week for `.alternatingWeeks`.
    var anchorDate: Date = Calendar.current.startOfDay(for: .now)
    var weeksOn: Int = 1
    var weeksOff: Int = 1
    /// Weekdays for `.weekdays` (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int> = []

    var summary: String {
        switch kind {
        case .always:
            return "Always"
        case .alternatingWeeks:
            if weeksOn == 1 && weeksOff == 1 { return "Every other week" }
            return "\(weeksOn) week\(weeksOn == 1 ? "" : "s") on, \(weeksOff) off"
        case .weekdays:
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().map { symbols[$0 - 1] }
            return names.isEmpty ? "Certain days" : names.joined(separator: ", ")
        }
    }
}

// MARK: - Alerts

enum AlertMode: String, Codable, CaseIterable, Identifiable {
    case none
    case notification
    case alarm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Silent (checklist only)"
        case .notification: return "Notification"
        case .alarm: return "Alarm (nags until done)"
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
