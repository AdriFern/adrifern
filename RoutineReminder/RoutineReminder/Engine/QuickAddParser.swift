import Foundation

/// Rule-based, fully offline parser for phrases like:
///   "Apply skincare every other day starting tonight"
///   "Take my pills every day at 8am"  /  "Tomar mis pastillas cada día a las 8"
///   "Homework at 5pm when I have Emma"  /  "Deberes a las 5 cuando tengo a Emma"
///   "Give Rocky his pill every 2 days at 7pm"  /  "Pastilla de Rocky cada 2 días a las 7 de la tarde"
///   "Pay rent monthly on the 1st"  /  "Pagar alquiler cada mes el 1"
/// Understands English and Spanish. No network, no AI tokens — just pattern
/// matching, with an editable preview before anything is saved.
struct ParsedReminder {
    var title: String
    var schedule: Schedule
    var timeMinutes: Int?
    var matchedContext: ContextTag?
    var notes: [String] = []
}

enum QuickAddParser {

    // MARK: Helpers

    private static let matchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Case/diacritic-insensitively removes every occurrence of `phrase`.
    @discardableResult
    private static func strip(_ phrase: String, from text: inout String) -> Bool {
        var found = false
        while let range = text.range(of: phrase, options: matchOptions) {
            text.replaceSubrange(range, with: " ")
            found = true
        }
        return found
    }

    private static func contains(_ phrase: String, in text: String) -> Bool {
        text.range(of: phrase, options: matchOptions) != nil
    }

    // MARK: Parse

    static func parse(_ input: String, contexts: [ContextTag], now: Date = .now) -> ParsedReminder? {
        // Keep original casing throughout; matching is case-insensitive.
        var text = " " + input + " "
        // Normalize "a.m."/"p.m." BEFORE punctuation stripping so meridiems survive.
        text = text.replacingOccurrences(of: "a.m.", with: "am", options: matchOptions)
        text = text.replacingOccurrences(of: "p.m.", with: "pm", options: matchOptions)
        text = text.replacingOccurrences(of: ",", with: " ")
        text = text.replacingOccurrences(of: ".", with: " ")
        text = " " + text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) + " "
        guard text.trimmingCharacters(in: .whitespaces).count > 2 else { return nil }

        var notes: [String] = []
        let calendar = Calendar.current

        // --- Leading command phrases (EN + ES)
        let prefixes = ["remind me to ", "remind me ", "reminder to ", "remember to ", "i need to ",
                        "i have to ", "set a reminder to ", "add ",
                        "recuérdame que ", "recuérdame ", "recordarme ", "recuerda que ", "avísame de ",
                        "avísame que ", "tengo que ", "necesito ", "añade ", "agrega ", "pon un recordatorio de "]
        var anchoredOptions = matchOptions
        anchoredOptions.insert(.anchored)
        for prefix in prefixes {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: prefix, options: anchoredOptions) {
                text = " " + String(trimmed[range.upperBound...]) + " "
                break
            }
        }

        // --- Context: "when I have <name>" (EN) / "cuando tengo a <name>" (ES)
        var matchedContext: ContextTag?
        for context in contexts {
            let name = context.name
            guard !name.isEmpty else { continue }
            let phrases = [
                "when i have \(name)", "when \(name) is with me", "when \(name) is here",
                "when \(name) is home", "while i have \(name)", "on \(name) weeks", "during \(name) weeks",
                "cuando tengo a \(name)", "cuando tenga a \(name)", "cuando \(name) está conmigo",
                "cuando \(name) esté conmigo", "las semanas de \(name)", "en las semanas de \(name)",
                "las semanas con \(name)",
            ]
            for phrase in phrases where contains(phrase, in: text) {
                matchedContext = context
                strip(phrase, from: &text)
                notes.append(String(localized: "Only on days \(context.name) is with you"))
                break
            }
            if matchedContext != nil { break }
        }

        var timeMinutes: Int?
        var startsToday = false
        var startsTomorrow = false
        var impliedDaily = false

        // --- Start-date phrases FIRST (multi-word, so "starting tonight" wins
        //     before the bare "tonight" pass strips its tail).
        let startTodayEvening = ["starting tonight", "empezando esta noche"]
        for phrase in startTodayEvening where strip(" \(phrase) ", from: &text) {
            startsToday = true
            if timeMinutes == nil { timeMinutes = 21 * 60 }
        }
        for phrase in ["starting today", "starting now", "from today", "empezando hoy", "desde hoy", "a partir de hoy"] where strip(" \(phrase) ", from: &text) {
            startsToday = true
        }
        for phrase in ["starting tomorrow", "from tomorrow", "empezando mañana", "desde mañana", "a partir de mañana"] where strip(" \(phrase) ", from: &text) {
            startsTomorrow = true
        }

        // --- Word times (EN + ES). "every morning" / "cada mañana" also imply daily.
        //     ES note: "por la mañana" (morning) must be handled before the bare
        //     "mañana" (tomorrow) pass below.
        let wordTimes: [(phrase: String, minutes: Int, daily: Bool, today: Bool)] = [
            ("tonight", 21 * 60, false, true), ("this evening", 19 * 60, false, true),
            ("this morning", 8 * 60, false, true),
            ("every evening", 19 * 60, true, false), ("every morning", 8 * 60, true, false),
            ("every night", 21 * 60, true, false), ("every afternoon", 15 * 60, true, false),
            ("in the evening", 19 * 60, false, false), ("in the morning", 8 * 60, false, false),
            ("in the afternoon", 15 * 60, false, false), ("at night", 21 * 60, false, false),
            ("at noon", 12 * 60, false, false), ("at midnight", 0, false, false),
            ("esta noche", 21 * 60, false, true), ("esta tarde", 15 * 60, false, true),
            ("esta mañana", 8 * 60, false, true),
            ("cada mañana", 8 * 60, true, false), ("cada noche", 21 * 60, true, false),
            ("cada tarde", 15 * 60, true, false), ("todas las mañanas", 8 * 60, true, false),
            ("todas las noches", 21 * 60, true, false), ("todas las tardes", 15 * 60, true, false),
            ("por la mañana", 8 * 60, false, false), ("por la noche", 21 * 60, false, false),
            ("por la tarde", 15 * 60, false, false), ("al mediodía", 12 * 60, false, false),
            ("a mediodía", 12 * 60, false, false), ("a medianoche", 0, false, false),
        ]
        for entry in wordTimes where strip(" \(entry.phrase) ", from: &text) {
            if timeMinutes == nil { timeMinutes = entry.minutes }
            if entry.daily { impliedDaily = true }
            if entry.today { startsToday = true }
        }

        // --- Bare "tomorrow" / "mañana" (after all "por la mañana" forms are gone)
        if strip(" tomorrow ", from: &text) { startsTomorrow = true }
        if strip(" mañana ", from: &text) { startsTomorrow = true }

        var startDate = calendar.startOfDay(for: now)
        if startsTomorrow, let tomorrow = calendar.date(byAdding: .day, value: 1, to: startDate) {
            startDate = tomorrow
        }

        // --- Numeric times. Spanish "a las 8 (de la tarde)" first, then English.
        var explicitMeridiem = false
        if timeMinutes == nil, let match = spanishTimeMatch(in: text) {
            timeMinutes = match.minutes
            explicitMeridiem = match.explicit
            text = text.replacingCharacters(in: match.range, with: " ")
        }
        if timeMinutes == nil, let match = englishTimeMatch(in: text) {
            timeMinutes = match.minutes
            explicitMeridiem = match.explicit
            text = text.replacingCharacters(in: match.range, with: " ")
        }
        // Meridiem-less small hours almost always mean the afternoon/evening:
        // "at 5" is 5 PM, not 5 AM.
        if var minutes = timeMinutes, !explicitMeridiem, (1...6).contains(minutes / 60) {
            minutes += 12 * 60
            timeMinutes = minutes
            notes.append(String(localized: "Assumed \(minutes.timeString) — edit if you meant the morning"))
        }

        // --- Recurrence
        var schedule = Schedule()
        schedule.kind = .once
        var foundRecurrence = false

        for phrase in ["every other day", "every second day", "every 2nd day",
                       "cada dos días", "un día sí y un día no", "días alternos", "cada otro día"] {
            if strip(" \(phrase) ", from: &text), !foundRecurrence {
                schedule.kind = .everyNDays
                schedule.interval = 2
                foundRecurrence = true
            }
        }
        for pattern in [#" every (\d+) days? "#, #" cada (\d+) d[ií]as? "#] {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let digits = text[match].filter { $0.isNumber }
                if !foundRecurrence {
                    schedule.kind = .everyNDays
                    schedule.interval = min(max(Int(digits) ?? 2, 1), 365)
                    foundRecurrence = true
                }
                text = text.replacingCharacters(in: match, with: " ")
            }
        }
        for phrase in ["every day", "everyday", "daily", "each day",
                       "cada día", "todos los días", "diariamente", "a diario"] {
            if strip(" \(phrase) ", from: &text), !foundRecurrence {
                schedule.kind = .daily
                foundRecurrence = true
            }
        }

        // Weekdays (EN + ES): "every monday"/"on mondays"/"los lunes" = weekly;
        // bare "on friday"/"el viernes" = one-time next occurrence.
        let weekdayNames: [(names: [String], number: Int)] = [
            (["sunday", "domingo"], 1), (["monday", "lunes"], 2), (["tuesday", "martes"], 3),
            (["wednesday", "miércoles"], 4), (["thursday", "jueves"], 5),
            (["friday", "viernes"], 6), (["saturday", "sábado"], 7),
        ]
        var weekdays: Set<Int> = []
        var onceWeekday: Int?
        var onceWeekdayExplicitNext = false
        for entry in weekdayNames {
            for name in entry.names {
                for variant in [" every \(name) ", " on \(name)s ", " \(name)s ", " cada \(name) ", " los \(name)s ", " los \(name) ", " las \(name)s "] {
                    if strip(variant, from: &text) { weekdays.insert(entry.number) }
                }
                for variant in [" next \(name) ", " el próximo \(name) ", " el proximo \(name) "] {
                    if strip(variant, from: &text) { onceWeekday = entry.number; onceWeekdayExplicitNext = true }
                }
                for variant in [" on \(name) ", " this \(name) ", " el \(name) ", " este \(name) "] {
                    if strip(variant, from: &text) { onceWeekday = entry.number }
                }
            }
        }
        for phrase in ["weekdays", "every weekday", "entre semana", "de lunes a viernes"] {
            if strip(" \(phrase) ", from: &text) { weekdays.formUnion([2, 3, 4, 5, 6]) }
        }
        for phrase in ["weekends", "every weekend", "los fines de semana", "cada fin de semana"] {
            if strip(" \(phrase) ", from: &text) { weekdays.formUnion([1, 7]) }
        }
        if !weekdays.isEmpty && !foundRecurrence {
            schedule.kind = .weekly
            schedule.weekdays = weekdays
            foundRecurrence = true
        }

        // Monthly (EN + ES)
        for pattern in [#" (monthly|every month)( on the (\d{1,2})(st|nd|rd|th)?)? "#,
                        #" (mensualmente|mensual|cada mes)( el (\d{1,2}))? "#] {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let digits = text[match].filter { $0.isNumber }
                if !foundRecurrence {
                    schedule.kind = .monthly
                    let day = Int(digits) ?? calendar.component(.day, from: startDate)
                    schedule.monthDays = [min(max(day, 1), 31)]
                    foundRecurrence = true
                }
                text = text.replacingCharacters(in: match, with: " ")
            }
        }

        // Bare "every week" → weekly on the start date's weekday
        for phrase in ["every week", "weekly", "cada semana", "semanalmente"] {
            if strip(" \(phrase) ", from: &text), !foundRecurrence {
                schedule.kind = .weekly
                schedule.weekdays = [calendar.component(.weekday, from: startDate)]
                foundRecurrence = true
            }
        }

        if !foundRecurrence && impliedDaily {
            schedule.kind = .daily
            foundRecurrence = true
        }

        // Bare "on friday" → one time, next occurrence of that weekday. If that
        // is today but the time already passed (or the user said "next"), jump
        // a full week.
        if !foundRecurrence, let weekday = onceWeekday {
            schedule.kind = .once
            var candidate = startDate
            for _ in 0..<7 {
                if calendar.component(.weekday, from: candidate) == weekday { break }
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            let isToday = calendar.isDate(candidate, inSameDayAs: now)
            let timePassed = (timeMinutes ?? (23 * 60 + 59)) <= now.minutesFromMidnight
            if isToday && (onceWeekdayExplicitNext || timePassed) {
                candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
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
                notes.append(String(localized: "That time already passed today, so it's set for tomorrow"))
            }
        }
        schedule.startDate = startDate

        // --- Title: what's left, cleaned of dangling connective words.
        var title = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–,;:¡!¿?"))
        let stopwords: Set<String> = ["and", "on", "at", "every", "starting", "from", "the", "a", "an", "in",
                                      "y", "el", "la", "los", "las", "en", "de", "del", "que", "para", "cada",
                                      "desde", "empezando", "am", "pm"]
        var words = title.split(separator: " ").map(String.init)
        while let last = words.last, stopwords.contains(last.lowercased()) { words.removeLast() }
        while let first = words.first, stopwords.contains(first.lowercased()) { words.removeFirst() }
        title = words.joined(separator: " ")
        guard !title.isEmpty else { return nil }
        title = title.prefix(1).uppercased() + title.dropFirst()

        return ParsedReminder(title: title,
                              schedule: schedule,
                              timeMinutes: timeMinutes,
                              matchedContext: matchedContext,
                              notes: notes)
    }

    // MARK: Numeric time matching

    /// English: "at 8", "at 8:30", "8pm", "8:30 pm", "at 20:15".
    /// A bare number ("2" in "every 2 days") is never a time: it needs
    /// a standalone "at", minutes, or a meridiem.
    private static func englishTimeMatch(in text: String) -> (minutes: Int, explicit: Bool, range: Range<String.Index>)? {
        let pattern = #"(?:\bat )?\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let full = nsText.substring(with: match.range)
            let hasAt = full.lowercased().hasPrefix("at ")
            let hasMinutes = match.range(at: 2).location != NSNotFound
            let meridiemRange = match.range(at: 3)
            let hasMeridiem = meridiemRange.location != NSNotFound
            guard hasAt || hasMinutes || hasMeridiem else { continue }

            guard var hour = Int(nsText.substring(with: match.range(at: 1))) else { continue }
            let minute = hasMinutes ? (Int(nsText.substring(with: match.range(at: 2))) ?? 0) : 0
            if hasMeridiem {
                let meridiem = nsText.substring(with: meridiemRange).lowercased()
                if meridiem.hasPrefix("p") && hour < 12 { hour += 12 }
                if meridiem.hasPrefix("a") && hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            guard let range = Range(match.range, in: text) else { continue }
            let explicit = hasMeridiem || hour > 12 || hour == 0
            return (hour * 60 + minute, explicit, range)
        }
        return nil
    }

    /// Spanish: "a las 8", "a la 1", "a las 8:30", "a las 8 de la tarde/noche/mañana".
    private static func spanishTimeMatch(in text: String) -> (minutes: Int, explicit: Bool, range: Range<String.Index>)? {
        let pattern = #"\ba las? (\d{1,2})(?::(\d{2}))?( de la (mañana|manana|tarde|noche)| de la madrugada)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard var hour = Int(nsText.substring(with: match.range(at: 1))) else { continue }
            let hasMinutes = match.range(at: 2).location != NSNotFound
            let minute = hasMinutes ? (Int(nsText.substring(with: match.range(at: 2))) ?? 0) : 0
            var explicit = hour > 12 || hour == 0
            if match.range(at: 3).location != NSNotFound {
                let qualifier = nsText.substring(with: match.range(at: 3)).lowercased()
                explicit = true
                if (qualifier.contains("tarde") || qualifier.contains("noche")) && hour < 12 { hour += 12 }
                if qualifier.contains("madrugada") && hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            guard let range = Range(match.range, in: text) else { continue }
            return (hour * 60 + minute, explicit, range)
        }
        return nil
    }
}
