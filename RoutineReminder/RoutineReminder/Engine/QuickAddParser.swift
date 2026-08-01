import Foundation

/// Rule-based, fully offline parser for phrases like:
///   "remind me to apply skincare every other day starting tonight at 9pm"
///   "take my pill every day at 8am"
///   "homework with my daughter at 5pm when I have Emma"
///   "water the plants on mondays and thursdays at 7pm"
///   "pay rent monthly on the 1st at 10am"
/// No network, no AI tokens — just pattern matching. The result is shown as an
/// editable preview before saving, so imperfect parses are easy to fix.
struct ParsedReminder {
    var title: String
    var schedule: Schedule
    var timeMinutes: Int?
    var matchedContext: ContextTag?
    var notes: [String] = []
}

enum QuickAddParser {

    static func parse(_ input: String, contexts: [ContextTag], now: Date = .now) -> ParsedReminder? {
        var text = " " + input.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "  ", with: " ") + " "
        guard text.trimmingCharacters(in: .whitespaces).count > 2 else { return nil }

        var notes: [String] = []
        let calendar = Calendar.current

        // --- Context: "when I have <name>" / "when <name> is with me/here/home"
        var matchedContext: ContextTag?
        for context in contexts {
            let name = context.name.lowercased()
            guard !name.isEmpty else { continue }
            let phrases = [
                "when i have \(name)", "when \(name) is with me", "when \(name) is here",
                "when \(name) is home", "while i have \(name)", "on \(name) weeks", "during \(name) weeks",
            ]
            for phrase in phrases where text.contains(phrase) {
                matchedContext = context
                text = text.replacingOccurrences(of: phrase, with: " ")
                notes.append("Only on \(context.name)'s weeks/days with you")
                break
            }
            if matchedContext != nil { break }
        }

        // --- Time of day
        var timeMinutes: Int?
        if let (minutes, range) = firstTimeMatch(in: text) {
            timeMinutes = minutes
            text = text.replacingCharacters(in: range, with: " ")
        }
        let wordTimes: [(String, Int)] = [
            (" tonight ", 21 * 60), (" this evening ", 19 * 60), (" every evening ", 19 * 60),
            (" in the evening ", 19 * 60), (" every morning ", 8 * 60), (" in the morning ", 8 * 60),
            (" this morning ", 8 * 60), (" at noon ", 12 * 60), (" at midnight ", 0),
            (" every night ", 21 * 60), (" at night ", 21 * 60), (" in the afternoon ", 15 * 60),
            (" every afternoon ", 15 * 60),
        ]
        var startsToday = false
        var startsTomorrow = false
        var impliedDaily = false
        for (phrase, minutes) in wordTimes where text.contains(phrase) {
            if timeMinutes == nil { timeMinutes = minutes }
            if phrase == " tonight " || phrase == " this evening " || phrase == " this morning " { startsToday = true }
            // "every morning/evening/night/afternoon" implies daily if nothing else says otherwise
            if phrase.hasPrefix(" every ") { impliedDaily = true }
            text = text.replacingOccurrences(of: phrase, with: " ")
        }

        // --- Start date
        var startDate = calendar.startOfDay(for: now)
        if text.contains(" starting tomorrow ") || text.contains(" from tomorrow ") {
            startsTomorrow = true
            text = text.replacingOccurrences(of: " starting tomorrow ", with: " ")
                .replacingOccurrences(of: " from tomorrow ", with: " ")
        }
        if text.contains(" tomorrow ") {
            startsTomorrow = true
            text = text.replacingOccurrences(of: " tomorrow ", with: " ")
        }
        for phrase in [" starting today ", " starting tonight ", " starting now ", " from today "] where text.contains(phrase) {
            startsToday = true
            if phrase == " starting tonight " && timeMinutes == nil { timeMinutes = 21 * 60 }
            text = text.replacingOccurrences(of: phrase, with: " ")
        }
        if startsTomorrow, let tomorrow = calendar.date(byAdding: .day, value: 1, to: startDate) {
            startDate = tomorrow
        }

        // --- Recurrence
        var schedule = Schedule(kind: .once)
        var foundRecurrence = false

        if text.contains(" every other day ") || text.contains(" every second day ") || text.contains(" every 2nd day ") {
            schedule.kind = .everyNDays
            schedule.interval = 2
            foundRecurrence = true
            text = text.replacingOccurrences(of: " every other day ", with: " ")
                .replacingOccurrences(of: " every second day ", with: " ")
                .replacingOccurrences(of: " every 2nd day ", with: " ")
        }
        if !foundRecurrence, let match = text.range(of: #" every (\d+) days? "#, options: .regularExpression) {
            let digits = text[match].filter { $0.isNumber }
            schedule.kind = .everyNDays
            schedule.interval = max(1, Int(digits) ?? 2)
            foundRecurrence = true
            text = text.replacingCharacters(in: match, with: " ")
        }
        for phrase in [" every day ", " everyday ", " daily ", " each day "] where text.contains(phrase) {
            if !foundRecurrence {
                schedule.kind = .daily
                foundRecurrence = true
            }
            text = text.replacingOccurrences(of: phrase, with: " ")
        }

        // Weekdays: "every monday", "on mondays and thursdays", "weekdays", "weekends"
        let weekdayNames: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7),
        ]
        var weekdays: Set<Int> = []
        var onceWeekday: Int?
        for (name, number) in weekdayNames {
            // "every friday" / "on fridays" / "fridays" = weekly; bare "on friday" = one time.
            for variant in [" every \(name) ", " on \(name)s ", " \(name)s "] where text.contains(variant) {
                weekdays.insert(number)
                text = text.replacingOccurrences(of: variant, with: " ")
            }
            for variant in [" on \(name) ", " next \(name) ", " this \(name) "] where text.contains(variant) {
                onceWeekday = number
                text = text.replacingOccurrences(of: variant, with: " ")
            }
        }
        if text.contains(" weekdays ") || text.contains(" every weekday ") {
            weekdays.formUnion([2, 3, 4, 5, 6])
            text = text.replacingOccurrences(of: " weekdays ", with: " ").replacingOccurrences(of: " every weekday ", with: " ")
        }
        if text.contains(" weekends ") || text.contains(" every weekend ") {
            weekdays.formUnion([1, 7])
            text = text.replacingOccurrences(of: " weekends ", with: " ").replacingOccurrences(of: " every weekend ", with: " ")
        }
        if !weekdays.isEmpty && !foundRecurrence {
            schedule.kind = .weekly
            schedule.weekdays = weekdays
            foundRecurrence = true
        }

        // Monthly: "monthly on the 1st", "every month on the 15th", "monthly"
        if let match = text.range(of: #" (monthly|every month)( on the (\d{1,2})(st|nd|rd|th)?)? "#, options: .regularExpression) {
            let digits = text[match].filter { $0.isNumber }
            schedule.kind = .monthly
            let day = Int(digits) ?? calendar.component(.day, from: startDate)
            schedule.monthDays = [min(max(day, 1), 31)]
            foundRecurrence = true
            text = text.replacingCharacters(in: match, with: " ")
        }

        // Bare "every week" → weekly on the start date's weekday
        if text.contains(" every week ") || text.contains(" weekly ") {
            if !foundRecurrence {
                schedule.kind = .weekly
                schedule.weekdays = [calendar.component(.weekday, from: startDate)]
                foundRecurrence = true
            }
            text = text.replacingOccurrences(of: " every week ", with: " ").replacingOccurrences(of: " weekly ", with: " ")
        }

        if !foundRecurrence && impliedDaily {
            schedule.kind = .daily
            foundRecurrence = true
        }

        // Bare "on friday" → one time, on the next occurrence of that weekday.
        if !foundRecurrence, let weekday = onceWeekday {
            schedule.kind = .once
            var candidate = startDate
            for _ in 0..<7 {
                if calendar.component(.weekday, from: candidate) == weekday { break }
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            startDate = candidate
            foundRecurrence = true
        }

        // One-time with a time that already passed today → tomorrow (unless "today" was explicit)
        if !foundRecurrence {
            schedule.kind = .once
            if let minutes = timeMinutes, !startsToday, !startsTomorrow,
               calendar.isDate(startDate, inSameDayAs: now), minutes <= now.minutesFromMidnight,
               let tomorrow = calendar.date(byAdding: .day, value: 1, to: startDate) {
                startDate = tomorrow
                notes.append("That time already passed today, so it's set for tomorrow")
            }
        }
        schedule.startDate = startDate

        // --- Title: what's left after stripping the matched phrases
        var title = text
        for prefix in ["remind me to ", "remind me ", "reminder to ", "remember to ", "i need to ", "i have to ", "set a reminder to ", "add "] {
            if title.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) {
                title = title.trimmingCharacters(in: .whitespaces)
                title.removeFirst(prefix.count)
                break
            }
        }
        title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–,;:"))
        guard !title.isEmpty else { return nil }
        title = title.prefix(1).capitalized + title.dropFirst()

        return ParsedReminder(title: title,
                              schedule: schedule,
                              timeMinutes: timeMinutes,
                              matchedContext: matchedContext,
                              notes: notes)
    }

    /// Finds "at 8", "at 8:30", "at 8pm", "8:30 pm", "at 20:15".
    private static func firstTimeMatch(in text: String) -> (minutes: Int, range: Range<String.Index>)? {
        let pattern = #"(?:at )?\b(\d{1,2})(?::(\d{2}))?\s?(am|pm|a\.m\.|p\.m\.)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let full = nsText.substring(with: match.range)
            let hasAt = full.hasPrefix("at ")
            let hasMinutes = match.range(at: 2).location != NSNotFound
            let meridiemRange = match.range(at: 3)
            let hasMeridiem = meridiemRange.location != NSNotFound
            // A bare number like "2" in "every 2 days" must not be read as a time:
            // require "at", minutes, or am/pm.
            guard hasAt || hasMinutes || hasMeridiem else { continue }

            guard var hour = Int(nsText.substring(with: match.range(at: 1))) else { continue }
            let minute = hasMinutes ? (Int(nsText.substring(with: match.range(at: 2))) ?? 0) : 0
            if hasMeridiem {
                let meridiem = nsText.substring(with: meridiemRange)
                if meridiem.hasPrefix("p") && hour < 12 { hour += 12 }
                if meridiem.hasPrefix("a") && hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            guard let range = Range(match.range, in: text) else { continue }
            return (hour * 60 + minute, range)
        }
        return nil
    }
}
