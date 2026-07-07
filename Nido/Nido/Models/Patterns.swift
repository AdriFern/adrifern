import Foundation

/// Recurring custody schedule templates.
enum PatternTemplate: String, CaseIterable, Identifiable {
    case alternatingWeeks
    case twoTwoThree
    case everyOtherWeekend
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alternatingWeeks: String(localized: "Alternating weeks")
        case .twoTwoThree: String(localized: "2-2-3 rotation")
        case .everyOtherWeekend: String(localized: "Every other weekend")
        case .weekly: String(localized: "Same days every week")
        }
    }

    var subtitle: String {
        switch self {
        case .alternatingWeeks: String(localized: "One full week each, taking turns")
        case .twoTwoThree: String(localized: "2 days, 2 days, then the weekend — swapping each week")
        case .everyOtherWeekend: String(localized: "One parent hosts weekdays, weekends alternate")
        case .weekly: String(localized: "Pick which weekdays belong to each parent")
        }
    }

    var symbolName: String {
        switch self {
        case .alternatingWeeks: "arrow.left.arrow.right"
        case .twoTwoThree: "circle.grid.2x2"
        case .everyOtherWeekend: "sun.max"
        case .weekly: "calendar"
        }
    }
}

enum PatternGenerator {
    /// Generates the proposed owner for every day between `start` and `end` (inclusive).
    /// `firstParent` is the parent the pattern starts with; for `.everyOtherWeekend`
    /// it is the weekday ("base") parent. For `.weekly`, `weekdaysForFirst` holds the
    /// weekday numbers (1 = Sunday ... 7 = Saturday) assigned to `firstParent`.
    static func generate(
        template: PatternTemplate,
        start: Date,
        end: Date,
        firstParent: ParentRole,
        weekdaysForFirst: Set<Int> = []
    ) -> [String: ParentRole] {
        let calendar = Day.calendar
        let startDay = calendar.startOfDay(for: start)
        var result: [String: ParentRole] = [:]

        for key in Day.keys(from: start, to: end) {
            guard let date = Day.date(from: key) else { continue }
            let dayIndex = calendar.dateComponents([.day], from: startDay, to: date).day ?? 0
            let weekday = calendar.component(.weekday, from: date)
            let owner: ParentRole

            switch template {
            case .alternatingWeeks:
                owner = (dayIndex / 7) % 2 == 0 ? firstParent : firstParent.other

            case .twoTwoThree:
                // 14-day cycle: 2 (A) + 2 (B) + 3 (A) + 2 (B) + 2 (A) + 3 (B)
                let cycle = dayIndex % 14
                let firstOwns = cycle < 2 || (4...6).contains(cycle) || (9...10).contains(cycle)
                owner = firstOwns ? firstParent : firstParent.other

            case .everyOtherWeekend:
                let isWeekend = weekday == 6 || weekday == 7 || weekday == 1 // Fri, Sat, Sun
                if !isWeekend {
                    owner = firstParent
                } else {
                    // Alternate whole weekends (Fri–Sun stay together) by
                    // anchoring each weekend to its Friday, so a mid-weekend
                    // start date can never split a weekend between parents.
                    let offsetToFriday = weekday == 6 ? 0 : (weekday == 7 ? 1 : 2)
                    let friday = calendar.date(byAdding: .day, value: -offsetToFriday, to: date) ?? date
                    let startWeekday = calendar.component(.weekday, from: startDay)
                    let daysSinceFriday = (startWeekday - 6 + 7) % 7
                    let anchorFriday = calendar.date(byAdding: .day, value: -daysSinceFriday, to: startDay) ?? startDay
                    let weekendIndex = (calendar.dateComponents([.day], from: anchorFriday, to: friday).day ?? 0) / 7
                    owner = weekendIndex % 2 == 1 ? firstParent.other : firstParent
                }

            case .weekly:
                owner = weekdaysForFirst.contains(weekday) ? firstParent : firstParent.other
            }

            result[key] = owner
        }
        return result
    }
}
