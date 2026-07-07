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
/// `assignedBy` records who set the day directly; days settled through an approved
/// change request have no `assignedBy` and are "locked" (only changeable by request).
struct DayAssignment: Codable, Equatable, Sendable {
    var dateKey: String
    var owner: ParentRole
    var assignedBy: ParentRole?

    static func recordName(for dateKey: String) -> String { "day-\(dateKey)" }

    init(dateKey: String, owner: ParentRole, assignedBy: ParentRole?) {
        self.dateKey = dateKey
        self.owner = owner
        self.assignedBy = assignedBy
    }

    init?(record: CKRecord) {
        guard record.recordType == RecordType.dayAssignment,
              let key = record["dateKey"] as? String,
              let rawOwner = record["owner"] as? String,
              let owner = ParentRole(rawValue: rawOwner)
        else { return nil }
        self.dateKey = key
        self.owner = owner
        self.assignedBy = (record["assignedBy"] as? String).flatMap(ParentRole.init(rawValue:))
    }

    func apply(to record: CKRecord) {
        record["dateKey"] = dateKey
        record["owner"] = owner.rawValue
        record["assignedBy"] = assignedBy?.rawValue ?? ""
    }
}

// MARK: - Change request

/// A single proposed day change inside a request. `oldOwner` captures the
/// assignment at proposal time (nil = unassigned) so approval can detect
/// days that changed in the meantime.
struct DayChange: Codable, Equatable, Hashable, Sendable {
    var dateKey: String
    var newOwner: ParentRole
    var oldOwner: ParentRole?

    var encoded: String { "\(dateKey)|\(newOwner.rawValue)|\(oldOwner?.rawValue ?? "-")" }

    init(dateKey: String, newOwner: ParentRole, oldOwner: ParentRole?) {
        self.dateKey = dateKey
        self.newOwner = newOwner
        self.oldOwner = oldOwner
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: "|")
        guard parts.count >= 2, let owner = ParentRole(rawValue: String(parts[1])) else { return nil }
        self.dateKey = String(parts[0])
        self.newOwner = owner
        self.oldOwner = parts.count >= 3 ? ParentRole(rawValue: String(parts[2])) : nil
    }
}

/// A proposal to change one or more assigned days, requiring the other parent's approval.
struct ChangeRequest: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending, approved, declined, cancelled
    }

    enum Kind: String, Codable, Sendable {
        case manual, pattern
    }

    var id: String
    var requester: ParentRole
    var changes: [DayChange]
    var message: String
    var status: Status
    var kind: Kind
    var createdAt: Date
    var resolvedAt: Date?

    var isPending: Bool { status == .pending }

    init(requester: ParentRole, changes: [DayChange], message: String, kind: Kind = .manual) {
        self.id = UUID().uuidString
        self.requester = requester
        self.changes = changes.sorted { $0.dateKey < $1.dateKey }
        self.message = message
        self.status = .pending
        self.kind = kind
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
        self.kind = (record["kind"] as? String).flatMap(Kind.init(rawValue:)) ?? .manual
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        self.resolvedAt = record["resolvedAt"] as? Date
        if changes.isEmpty { return nil }
    }

    func apply(to record: CKRecord) {
        record["requester"] = requester.rawValue
        record["changes"] = changes.map(\.encoded)
        record["message"] = message
        record["status"] = status.rawValue
        record["kind"] = kind.rawValue
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

    /// Localized, human-readable color names (for VoiceOver).
    static func name(for hex: String) -> String {
        switch hex {
        case "#FF7769": String(localized: "Coral")
        case "#F4A259": String(localized: "Apricot")
        case "#F2C14E": String(localized: "Honey")
        case "#7CB57B": String(localized: "Sage")
        case "#43AA8B": String(localized: "Jade")
        case "#4EA8DE": String(localized: "Sky blue")
        case "#5E7CE2": String(localized: "Periwinkle")
        case "#9D69C9": String(localized: "Lavender")
        case "#E36BAE": String(localized: "Rose")
        case "#8D99AE": String(localized: "Slate")
        default: String(localized: "Color option")
        }
    }
}
