import CloudKit
import Foundation

// MARK: - Record types

enum RecordType {
    static let family = "Family"
    static let dayAssignment = "DayAssignment"
    static let changeRequest = "ChangeRequest"
    static let dayNote = "DayNote"
}

// MARK: - Parent role

/// Parent A is the person who created the family calendar; parent B joined it.
enum ParentRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case parentA = "A"
    case parentB = "B"

    var id: String { rawValue }
    var other: ParentRole { self == .parentA ? .parentB : .parentA }
}

// MARK: - Family

struct Family: Codable, Equatable, Sendable {
    var childName: String
    var nameA: String
    var nameB: String
    var colorA: String
    var colorB: String

    static let recordName = "family"

    var partnerHasJoined: Bool { !nameB.trimmingCharacters(in: .whitespaces).isEmpty }

    func name(of role: ParentRole) -> String {
        let raw = role == .parentA ? nameA : nameB
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return role == .parentA
            ? String(localized: "Parent 1")
            : String(localized: "Co-parent")
    }

    func colorHex(of role: ParentRole) -> String {
        role == .parentA ? colorA : colorB
    }

    // MARK: CKRecord mapping

    init?(record: CKRecord) {
        guard record.recordType == RecordType.family else { return nil }
        childName = record["childName"] as? String ?? ""
        nameA = record["nameA"] as? String ?? ""
        nameB = record["nameB"] as? String ?? ""
        colorA = record["colorA"] as? String ?? Palette.defaultA
        colorB = record["colorB"] as? String ?? Palette.defaultB
    }

    init(childName: String, nameA: String, nameB: String = "", colorA: String, colorB: String = Palette.defaultB) {
        self.childName = childName
        self.nameA = nameA
        self.nameB = nameB
        self.colorA = colorA
        self.colorB = colorB
    }

    func apply(to record: CKRecord) {
        record["childName"] = childName
        record["nameA"] = nameA
        record["nameB"] = nameB
        record["colorA"] = colorA
        record["colorB"] = colorB
    }
}

// MARK: - Day assignment

/// Which parent has the child on a given day. Unassigned days simply have no record.
struct DayAssignment: Codable, Equatable, Sendable {
    var dateKey: String
    var owner: ParentRole

    static func recordName(for dateKey: String) -> String { "day-\(dateKey)" }

    init(dateKey: String, owner: ParentRole) {
        self.dateKey = dateKey
        self.owner = owner
    }

    init?(record: CKRecord) {
        guard record.recordType == RecordType.dayAssignment,
              let key = record["dateKey"] as? String,
              let rawOwner = record["owner"] as? String,
              let owner = ParentRole(rawValue: rawOwner)
        else { return nil }
        self.dateKey = key
        self.owner = owner
    }

    func apply(to record: CKRecord) {
        record["dateKey"] = dateKey
        record["owner"] = owner.rawValue
    }
}

// MARK: - Change request

/// A single proposed day change inside a request.
struct DayChange: Codable, Equatable, Hashable, Sendable {
    var dateKey: String
    var newOwner: ParentRole

    var encoded: String { "\(dateKey)|\(newOwner.rawValue)" }

    init(dateKey: String, newOwner: ParentRole) {
        self.dateKey = dateKey
        self.newOwner = newOwner
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: "|")
        guard parts.count == 2, let owner = ParentRole(rawValue: String(parts[1])) else { return nil }
        self.dateKey = String(parts[0])
        self.newOwner = owner
    }
}

/// A proposal to change one or more assigned days, requiring the other parent's approval.
struct ChangeRequest: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending, approved, declined, cancelled
    }

    var id: String
    var requester: ParentRole
    var changes: [DayChange]
    var message: String
    var status: Status
    var createdAt: Date
    var resolvedAt: Date?

    var isPending: Bool { status == .pending }

    init(requester: ParentRole, changes: [DayChange], message: String) {
        self.id = UUID().uuidString
        self.requester = requester
        self.changes = changes.sorted { $0.dateKey < $1.dateKey }
        self.message = message
        self.status = .pending
        self.createdAt = Date()
        self.resolvedAt = nil
    }

    init?(record: CKRecord) {
        guard record.recordType == RecordType.changeRequest,
              let rawRequester = record["requester"] as? String,
              let requester = ParentRole(rawValue: rawRequester),
              let encodedChanges = record["changes"] as? [String],
              let rawStatus = record["status"] as? String,
              let status = Status(rawValue: rawStatus)
        else { return nil }
        self.id = record.recordID.recordName
        self.requester = requester
        self.changes = encodedChanges.compactMap(DayChange.init(encoded:))
        self.message = record["message"] as? String ?? ""
        self.status = status
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        self.resolvedAt = record["resolvedAt"] as? Date
        if changes.isEmpty { return nil }
    }

    func apply(to record: CKRecord) {
        record["requester"] = requester.rawValue
        record["changes"] = changes.map(\.encoded)
        record["message"] = message
        record["status"] = status.rawValue
        record["createdAt"] = createdAt
        record["resolvedAt"] = resolvedAt
    }
}

// MARK: - Day note

/// A short shared note attached to a day (e.g. "Dentist at 5pm").
struct DayNote: Codable, Equatable, Sendable {
    var dateKey: String
    var text: String

    static func recordName(for dateKey: String) -> String { "note-\(dateKey)" }

    init(dateKey: String, text: String) {
        self.dateKey = dateKey
        self.text = text
    }

    init?(record: CKRecord) {
        guard record.recordType == RecordType.dayNote,
              let key = record["dateKey"] as? String,
              let text = record["text"] as? String
        else { return nil }
        self.dateKey = key
        self.text = text
    }

    func apply(to record: CKRecord) {
        record["dateKey"] = dateKey
        record["text"] = text
    }
}

// MARK: - Color palette

enum Palette {
    static let defaultA = "#FF7769"
    static let defaultB = "#4EA8DE"

    /// Curated, friendly colors that read well as calendar day fills in light and dark mode.
    static let options: [String] = [
        "#FF7769", // coral
        "#F4A259", // apricot
        "#F2C14E", // honey
        "#7CB57B", // sage
        "#43AA8B", // jade
        "#4EA8DE", // sky
        "#5E7CE2", // periwinkle
        "#9D69C9", // lavender
        "#E36BAE", // rose
        "#8D99AE", // slate
    ]
}
