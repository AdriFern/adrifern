import Foundation
import SwiftData

// MARK: - Context ("People & Pets")
//
// A context represents someone (or something) whose presence follows a pattern:
// a daughter on alternating custody weeks, a shared pet, or "always" for yourself.
// Routines can be linked to a context so they only occur on days the context is active.

@Model
final class ContextTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    var colorName: String
    var patternData: Data
    var createdAt: Date

    init(name: String, symbol: String = "person", colorName: String = "purple", pattern: PresencePattern = PresencePattern()) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.colorName = colorName
        self.patternData = (try? JSONEncoder().encode(pattern)) ?? Data()
        self.createdAt = .now
    }

    var pattern: PresencePattern {
        get { (try? JSONDecoder().decode(PresencePattern.self, from: patternData)) ?? PresencePattern() }
        set { patternData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

// MARK: - Routine

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var symbol: String
    var colorName: String
    var isEnabled: Bool
    /// Optional link to a ContextTag; the routine only occurs on days the context is active.
    var contextID: UUID?
    var scheduleData: Data
    /// Times of day as minutes from midnight (e.g. 480 = 8:00 AM). Empty = all-day task.
    var timesMinutes: [Int]
    var alertModeRaw: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.routine)
    var items: [ChecklistItem] = []

    init(title: String,
         notes: String = "",
         symbol: String = "pills",
         colorName: String = "blue",
         schedule: Schedule = Schedule(),
         timesMinutes: [Int] = [9 * 60],
         alertMode: AlertMode = .notification,
         contextID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.symbol = symbol
        self.colorName = colorName
        self.isEnabled = true
        self.contextID = contextID
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.timesMinutes = timesMinutes
        self.alertModeRaw = alertMode.rawValue
        self.createdAt = .now
    }

    var schedule: Schedule {
        get { (try? JSONDecoder().decode(Schedule.self, from: scheduleData)) ?? Schedule() }
        set { scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var alertMode: AlertMode {
        get { AlertMode(rawValue: alertModeRaw) ?? .notification }
        set { alertModeRaw = newValue.rawValue }
    }

    var sortedItems: [ChecklistItem] {
        items.sorted { $0.order < $1.order }
    }
}

@Model
final class ChecklistItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var order: Int
    var routine: Routine?

    init(title: String, order: Int) {
        self.id = UUID()
        self.title = title
        self.order = order
    }
}

// MARK: - Completion log
//
// One record per (routine, day, time slot). Checklist progress for that
// occurrence is tracked via completedItemIDs.

@Model
final class CompletionRecord {
    var routineID: UUID
    var dayKey: String
    var slotMinutes: Int
    var completedItemIDs: [UUID]
    var isDone: Bool
    var completedAt: Date?

    init(routineID: UUID, dayKey: String, slotMinutes: Int) {
        self.routineID = routineID
        self.dayKey = dayKey
        self.slotMinutes = slotMinutes
        self.completedItemIDs = []
        self.isDone = false
        self.completedAt = nil
    }
}
