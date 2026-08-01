import Foundation

/// A single reminder instance on a specific day at a specific time slot.
struct Occurrence: Identifiable, Hashable {
    let routineID: UUID
    let day: Date          // start of day
    let slotMinutes: Int   // minutes from midnight; -1 for all-day tasks

    var id: String { "\(routineID.uuidString)-\(Scheduler.dayKey(for: day))-\(slotMinutes)" }

    /// The concrete fire date (day + slot). All-day tasks fire at 9:00 AM.
    var fireDate: Date {
        let minutes = slotMinutes >= 0 ? slotMinutes : 9 * 60
        return Calendar.current.date(byAdding: .minute, value: minutes, to: day) ?? day
    }
}

enum Scheduler {

    static var calendar: Calendar { Calendar.current }

    // MARK: Day keys

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    // MARK: Context presence

    static func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func isContextActive(_ pattern: PresencePattern, on date: Date) -> Bool {
        switch pattern.kind {
        case .always:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return pattern.weekdays.contains(weekday)
        case .alternatingWeeks:
            let cycle = max(1, pattern.weeksOn) + max(0, pattern.weeksOff)
            let anchorWeek = startOfWeek(pattern.anchorDate)
            let thisWeek = startOfWeek(date)
            let days = calendar.dateComponents([.day], from: anchorWeek, to: thisWeek).day ?? 0
            let weekIndex = Int((Double(days) / 7.0).rounded())
            let position = ((weekIndex % cycle) + cycle) % cycle
            return position < max(1, pattern.weeksOn)
        }
    }

    // MARK: Recurrence

    static func occurs(_ schedule: Schedule, on date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: schedule.startDate)
        guard day >= start else { return false }
        if let end = schedule.endDate, day > calendar.startOfDay(for: end) { return false }

        switch schedule.kind {
        case .daily:
            return true
        case .everyNDays:
            let n = max(1, schedule.interval)
            let days = calendar.dateComponents([.day], from: start, to: day).day ?? 0
            return days % n == 0
        case .weekly:
            return schedule.weekdays.contains(calendar.component(.weekday, from: day))
        case .monthly:
            return schedule.monthDays.contains(calendar.component(.day, from: day))
        case .once:
            return calendar.isDate(day, inSameDayAs: start)
        }
    }

    static func routineOccurs(_ routine: Routine, on date: Date, contexts: [UUID: ContextTag]) -> Bool {
        guard routine.isEnabled, occurs(routine.schedule, on: date) else { return false }
        if let contextID = routine.contextID, let context = contexts[contextID] {
            return isContextActive(context.pattern, on: date)
        }
        return true
    }

    // MARK: Occurrence generation

    static func occurrences(for routines: [Routine], contexts: [ContextTag], on date: Date) -> [Occurrence] {
        let day = calendar.startOfDay(for: date)
        let contextMap = Dictionary(uniqueKeysWithValues: contexts.map { ($0.id, $0) })
        var result: [Occurrence] = []
        for routine in routines where routineOccurs(routine, on: day, contexts: contextMap) {
            if routine.timesMinutes.isEmpty {
                result.append(Occurrence(routineID: routine.id, day: day, slotMinutes: -1))
            } else {
                for slot in routine.timesMinutes.sorted() {
                    result.append(Occurrence(routineID: routine.id, day: day, slotMinutes: slot))
                }
            }
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }

    /// Upcoming occurrences across the next `days` days, for notification scheduling.
    static func upcomingOccurrences(for routines: [Routine], contexts: [ContextTag], days: Int, from now: Date = .now) -> [Occurrence] {
        var result: [Occurrence] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            result.append(contentsOf: occurrences(for: routines, contexts: contexts, on: date))
        }
        return result.filter { $0.fireDate > now }.sorted { $0.fireDate < $1.fireDate }
    }

    /// Which weeks a context is active, for editor previews: next `weeks` week ranges with on/off flag.
    static func weekPreview(for pattern: PresencePattern, weeks: Int = 6, from date: Date = .now) -> [(range: String, active: Bool)] {
        var result: [(range: String, active: Bool)] = []
        let thisWeek = startOfWeek(date)
        for i in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: i, to: thisWeek),
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let active = isContextActive(pattern, on: weekStart)
            let label = weekStart.formatted(.dateTime.month(.abbreviated).day()) + " – " + weekEnd.formatted(.dateTime.month(.abbreviated).day())
            result.append((label, active))
        }
        return result
    }
}
