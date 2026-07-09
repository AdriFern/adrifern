import Foundation

/// Deterministic fairness insights over one member's assigned days.
/// Everything is computed on device from the calendar itself — it needs
/// no AI and works on every iPhone. Informational only: it never judges,
/// it just surfaces patterns both parents can see for themselves.
enum EquityAnalysis {
    struct Insight: Identifiable {
        enum Kind {
            case balanced, weekends, recentTilt, streak
        }
        let kind: Kind
        let text: String
        var id: String { text }

        var symbolName: String {
            switch kind {
            case .balanced: "checkmark.seal.fill"
            case .weekends: "sun.max.fill"
            case .recentTilt: "chart.line.uptrend.xyaxis"
            case .streak: "flame.fill"
            }
        }
    }

    static func insights(
        assignments: [String: ParentRole],
        family: Family,
        now: Date = Date()
    ) -> [Insight] {
        var result: [Insight] = []

        // Weekend balance over the last 8 weeks.
        let calendar = Day.calendar
        let start = calendar.date(byAdding: .day, value: -55, to: now) ?? now
        var weekendA = 0, weekendB = 0
        for key in Day.keys(from: start, to: now) {
            guard let owner = assignments[key],
                  let date = Day.date(from: key),
                  calendar.isDateInWeekend(date)
            else { continue }
            if owner == .parentA { weekendA += 1 } else { weekendB += 1 }
        }
        let weekendTotal = weekendA + weekendB
        if weekendTotal >= 4, abs(weekendA - weekendB) >= max(3, weekendTotal / 3) {
            result.append(Insight(
                kind: .weekends,
                text: String(localized: "Weekend days in the last 8 weeks: \(family.name(of: .parentA)) \(weekendA) · \(family.name(of: .parentB)) \(weekendB).")
            ))
        }

        // Recent tilt: last 30 days vs. the whole current year.
        let yearPrefix = String(Day.key(for: now).prefix(5))
        var yearA = 0, yearB = 0
        for (key, owner) in assignments where key.hasPrefix(yearPrefix) {
            if owner == .parentA { yearA += 1 } else { yearB += 1 }
        }
        let start30 = calendar.date(byAdding: .day, value: -29, to: now) ?? now
        var recentA = 0, recentB = 0
        for key in Day.keys(from: start30, to: now) {
            guard let owner = assignments[key] else { continue }
            if owner == .parentA { recentA += 1 } else { recentB += 1 }
        }
        let yearTotal = yearA + yearB, recentTotal = recentA + recentB
        if yearTotal >= 30, recentTotal >= 10 {
            let yearShare = Double(yearA) / Double(yearTotal)
            let recentShare = Double(recentA) / Double(recentTotal)
            if abs(recentShare - yearShare) >= 0.15 {
                let tiltedToA = recentShare > yearShare
                let name = family.name(of: tiltedToA ? .parentA : .parentB)
                let recentPct = (tiltedToA ? recentShare : 1 - recentShare)
                    .formatted(.percent.precision(.fractionLength(0)))
                let yearPct = (tiltedToA ? yearShare : 1 - yearShare)
                    .formatted(.percent.precision(.fractionLength(0)))
                result.append(Insight(
                    kind: .recentTilt,
                    text: String(localized: "In the last 30 days \(name) has had \(recentPct) of the assigned days (overall this year: \(yearPct)).")
                ))
            }
        }

        // Current streak ending today (or still running through today).
        var streak = 0
        var streakOwner: ParentRole?
        var cursor = now
        while let owner = assignments[Day.key(for: cursor)] {
            if streakOwner == nil { streakOwner = owner }
            guard owner == streakOwner else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        if streak >= 5, let owner = streakOwner {
            result.append(Insight(
                kind: .streak,
                text: String(localized: "\(family.name(of: owner)) is currently on a run of \(streak) days in a row.")
            ))
        }

        if result.isEmpty {
            result.append(Insight(
                kind: .balanced,
                text: String(localized: "No notable imbalances in the last 8 weeks — the split looks balanced.")
            ))
        }
        return result
    }
}
