import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup / restore
//
// Everything lives on-device, so the user owns backup. Export produces a
// single JSON file with routines, people/pets, and completion history;
// import merges by ID (safe to re-import — nothing duplicates).

struct BackupFile: Codable {
    var version = 1
    var exportedAt = Date.now
    var contexts: [ContextDTO] = []
    var routines: [RoutineDTO] = []
    var completions: [CompletionDTO] = []

    struct ContextDTO: Codable {
        var id: UUID
        var name: String
        var symbol: String
        var colorName: String
        var pattern: PresencePattern
    }

    struct RoutineDTO: Codable {
        var id: UUID
        var title: String
        var notes: String
        var symbol: String
        var colorName: String
        var isEnabled: Bool
        var contextID: UUID?
        var schedule: Schedule
        var timesMinutes: [Int]
        var alertMode: AlertMode
        var items: [ItemDTO]
    }

    struct ItemDTO: Codable {
        var id: UUID
        var title: String
        var order: Int
    }

    struct CompletionDTO: Codable {
        var routineID: UUID
        var dayKey: String
        var slotMinutes: Int
        var completedItemIDs: [UUID]
        var isDone: Bool
        var completedAt: Date?
    }
}

enum BackupManager {

    static func export(from context: ModelContext) throws -> Data {
        var file = BackupFile()
        let contexts = try context.fetch(FetchDescriptor<ContextTag>())
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let completions = try context.fetch(FetchDescriptor<CompletionRecord>())

        file.contexts = contexts.map {
            .init(id: $0.id, name: $0.name, symbol: $0.symbol, colorName: $0.colorName, pattern: $0.pattern)
        }
        file.routines = routines.map { routine in
            .init(id: routine.id, title: routine.title, notes: routine.notes, symbol: routine.symbol,
                  colorName: routine.colorName, isEnabled: routine.isEnabled, contextID: routine.contextID,
                  schedule: routine.schedule, timesMinutes: routine.timesMinutes, alertMode: routine.alertMode,
                  items: routine.sortedItems.map { .init(id: $0.id, title: $0.title, order: $0.order) })
        }
        file.completions = completions.map {
            .init(routineID: $0.routineID, dayKey: $0.dayKey, slotMinutes: $0.slotMinutes,
                  completedItemIDs: $0.completedItemIDs, isDone: $0.isDone, completedAt: $0.completedAt)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// Merge-import: existing objects (matched by ID) are updated, new ones
    /// inserted. Never deletes anything.
    static func importBackup(_ data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        let existingContexts = try context.fetch(FetchDescriptor<ContextTag>())
        let contextByID = Dictionary(uniqueKeysWithValues: existingContexts.map { ($0.id, $0) })
        for dto in file.contexts {
            if let existing = contextByID[dto.id] {
                existing.name = dto.name
                existing.symbol = dto.symbol
                existing.colorName = dto.colorName
                existing.pattern = dto.pattern
            } else {
                let context2 = ContextTag(name: dto.name, symbol: dto.symbol, colorName: dto.colorName, pattern: dto.pattern)
                context2.id = dto.id
                context.insert(context2)
            }
        }

        let existingRoutines = try context.fetch(FetchDescriptor<Routine>())
        let routineByID = Dictionary(uniqueKeysWithValues: existingRoutines.map { ($0.id, $0) })
        for dto in file.routines {
            let routine: Routine
            if let existing = routineByID[dto.id] {
                routine = existing
            } else {
                routine = Routine(title: dto.title)
                routine.id = dto.id
                context.insert(routine)
            }
            routine.title = dto.title
            routine.notes = dto.notes
            routine.symbol = dto.symbol
            routine.colorName = dto.colorName
            routine.isEnabled = dto.isEnabled
            routine.contextID = dto.contextID
            routine.schedule = dto.schedule
            routine.timesMinutes = dto.timesMinutes
            routine.alertMode = dto.alertMode

            let existingItems = Dictionary(uniqueKeysWithValues: routine.items.map { ($0.id, $0) })
            for itemDTO in dto.items {
                if let item = existingItems[itemDTO.id] {
                    item.title = itemDTO.title
                    item.order = itemDTO.order
                } else {
                    let item = ChecklistItem(id: itemDTO.id, title: itemDTO.title, order: itemDTO.order)
                    item.routine = routine
                    context.insert(item)
                }
            }
        }

        for dto in file.completions {
            if let record = CompletionStore.record(for: dto.routineID, dayKey: dto.dayKey,
                                                   slotMinutes: dto.slotMinutes, in: context, createIfMissing: true) {
                record.isDone = record.isDone || dto.isDone
                record.completedItemIDs = Array(Set(record.completedItemIDs).union(dto.completedItemIDs))
                if record.completedAt == nil { record.completedAt = dto.completedAt }
            }
        }

        try context.save()
    }
}

// MARK: - FileDocument wrapper for fileExporter

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
