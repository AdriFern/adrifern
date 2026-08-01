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
        set {
            // Never overwrite good data with an empty blob on a failed encode.
            if let data = try? JSONEncoder().encode(newValue) { patternData = data }
        }
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
         symbol: String = "checklist",
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
        set {
            if let data = try? JSONEncoder().encode(newValue) { scheduleData = data }
        }
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

    init(id: UUID = UUID(), title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

// MARK: - Completion log
//
// One record per (routine, day, time slot). Checklist progress for that
// occurrence is tracked via completedItemIDs. Uniqueness of the triple is
// enforced by the shared upsert in CompletionStore (SwiftData on iOS 17 has
// no compound unique constraints).

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

// MARK: - Shared completion upsert

enum CompletionStore {

    /// The single path for finding-or-creating a completion record, used by
    /// both the UI and the notification-action handler so the two can never
    /// race into duplicates. Also lazily merges any pre-existing duplicates.
    static func record(for routineID: UUID, dayKey: String, slotMinutes: Int,
                       in context: ModelContext, createIfMissing: Bool) -> CompletionRecord? {
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate<CompletionRecord> {
                $0.routineID == routineID && $0.dayKey == dayKey && $0.slotMinutes == slotMinutes
            }
        )
        let matches = (try? context.fetch(descriptor)) ?? []
        if let first = matches.first {
            if matches.count > 1 {
                for dupe in matches.dropFirst() {
                    first.isDone = first.isDone || dupe.isDone
                    first.completedItemIDs = Array(Set(first.completedItemIDs).union(dupe.completedItemIDs))
                    if first.completedAt == nil { first.completedAt = dupe.completedAt }
                    context.delete(dupe)
                }
            }
            return first
        }
        guard createIfMissing else { return nil }
        let record = CompletionRecord(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes)
        context.insert(record)
        return record
    }

    /// Removes all completion history for a deleted routine so the store
    /// never accumulates unreachable records.
    static func deleteRecords(for routineID: UUID, in context: ModelContext) {
        try? context.delete(model: CompletionRecord.self,
                            where: #Predicate<CompletionRecord> { $0.routineID == routineID })
    }
}
