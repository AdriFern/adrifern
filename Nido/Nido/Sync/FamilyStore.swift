import CloudKit
import Foundation
import Observation
import UserNotifications

/// Central app state: holds the family, day assignments, notes and change
/// requests, and coordinates every CloudKit operation.
@MainActor
@Observable
final class FamilyStore {

    enum Phase: Equatable {
        case loading
        case onboarding
        case ready
    }

    struct AppAlert: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var message: String
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .loading
    private(set) var family: Family?
    private(set) var assignments: [String: ParentRole] = [:]
    private(set) var notes: [String: String] = [:]
    private(set) var requests: [ChangeRequest] = []
    private(set) var myRole: ParentRole = .parentA
    private(set) var shareURL: URL?
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    /// True while a joiner has accepted an invitation but hasn't entered
    /// their name/color yet.
    private(set) var joinNeedsProfile = false
    var isAcceptingInvite = false

    var alert: AppAlert?

    // MARK: - Derived state

    var otherRole: ParentRole { myRole.other }

    var myName: String { family?.name(of: myRole) ?? String(localized: "Me") }
    var otherName: String { family?.name(of: otherRole) ?? String(localized: "Co-parent") }

    var pendingIncoming: [ChangeRequest] {
        requests.filter { $0.isPending && $0.requester != myRole }
    }
    var pendingOutgoing: [ChangeRequest] {
        requests.filter { $0.isPending && $0.requester == myRole }
    }
    var resolvedRequests: [ChangeRequest] {
        requests.filter { !$0.isPending }.sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
    }

    /// Date keys that appear in any pending request (to badge calendar cells).
    var pendingDateKeys: Set<String> {
        Set(requests.filter(\.isPending).flatMap { $0.changes.map(\.dateKey) })
    }

    // MARK: - Private

    private var service: CloudKitService
    private var setupComplete = false
    private var hasZoneAccess = false

    private enum Keys {
        static let role = "nido.role"
        static let setupComplete = "nido.setupComplete"
        static let zoneOwnerName = "nido.zoneOwnerName"
        static let changeToken = "nido.changeToken"
        static let shareURL = "nido.shareURL"
        static let requestStatuses = "nido.requestStatuses"
        static let joinNeedsProfile = "nido.joinNeedsProfile"
    }

    init() {
        let defaults = UserDefaults.standard
        let role = ParentRole(rawValue: defaults.string(forKey: Keys.role) ?? "A") ?? .parentA
        service = CloudKitService(
            isOwner: role == .parentA,
            zoneOwnerName: defaults.string(forKey: Keys.zoneOwnerName)
        )
        myRole = role
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard phase == .loading else { return }
        let defaults = UserDefaults.standard
        setupComplete = defaults.bool(forKey: Keys.setupComplete)
        joinNeedsProfile = defaults.bool(forKey: Keys.joinNeedsProfile)
        if let urlString = defaults.string(forKey: Keys.shareURL) {
            shareURL = URL(string: urlString)
        }

        if setupComplete {
            hasZoneAccess = true
            loadCache()
            phase = .ready
            await refresh()
        } else if joinNeedsProfile {
            hasZoneAccess = true
            loadCache()
            phase = .onboarding
            await refresh()
        } else {
            phase = .onboarding
        }
    }

    func checkAccountStatus() async -> Bool {
        do {
            let status = try await service.accountStatus()
            if status == .available { return true }
            alert = AppAlert(
                title: String(localized: "iCloud needed"),
                message: String(localized: "Nido keeps your calendar in sync through iCloud. Please sign in to iCloud in the iPhone Settings app, then try again.")
            )
            return false
        } catch {
            presentError(error)
            return false
        }
    }

    // MARK: - Create family (parent A)

    func createFamily(myName: String, childName: String, colorHex: String) async -> Bool {
        guard await checkAccountStatus() else { return false }
        do {
            service.configure(isOwner: true, zoneOwnerName: nil)
            let shareTitle = String(localized: "Custody calendar for \(childName)")
            let url = try await service.createZoneAndShare(title: shareTitle)

            var newFamily = Family(childName: childName, nameA: myName, colorA: colorHex)
            if colorHex == newFamily.colorB {
                newFamily.colorB = Palette.options.first { $0 != colorHex } ?? Palette.defaultB
            }
            let record = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName)
            newFamily.apply(to: record)
            try await service.save(records: [record])

            family = newFamily
            shareURL = url
            myRole = .parentA
            markSetupComplete(role: .parentA, zoneOwnerName: nil)
            UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL)

            await finishSetupSideEffects()
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    /// Moves from onboarding into the main app (used after the invite screen).
    func enterApp() {
        phase = .ready
    }

    // MARK: - Join family (parent B)

    /// Called when iOS hands us an accepted CloudKit share, or after we
    /// accept one manually from a pasted/scanned invitation link.
    func handleIncomingShare(_ metadata: CKShare.Metadata) async {
        if setupComplete {
            alert = AppAlert(
                title: String(localized: "Already connected"),
                message: String(localized: "This device is already part of a family calendar. To join a different one, first leave the current calendar in Settings.")
            )
            return
        }
        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        let ownerName = metadata.share.recordID.zoneID.ownerName
        do {
            try await service.acceptShare(metadata: metadata)
        } catch {
            // The share may already be accepted (e.g. tapping the link twice).
            // If we can reach the zone anyway, carry on; otherwise surface it.
            service.configure(isOwner: false, zoneOwnerName: ownerName)
            hasZoneAccess = true
            await refresh(silent: true)
            if family == nil {
                hasZoneAccess = false
                presentError(error)
                return
            }
        }

        service.configure(isOwner: false, zoneOwnerName: ownerName)
        myRole = .parentB
        hasZoneAccess = true
        joinNeedsProfile = true

        let defaults = UserDefaults.standard
        defaults.set(ParentRole.parentB.rawValue, forKey: Keys.role)
        defaults.set(ownerName, forKey: Keys.zoneOwnerName)
        defaults.set(true, forKey: Keys.joinNeedsProfile)
        defaults.removeObject(forKey: Keys.changeToken)

        phase = .onboarding
        await refresh()
    }

    /// Fallback join path: the invitation URL pasted or scanned inside the app.
    func join(with url: URL) async {
        isAcceptingInvite = true
        do {
            let metadata = try await service.fetchShareMetadata(for: url)
            isAcceptingInvite = false
            await handleIncomingShare(metadata)
        } catch {
            isAcceptingInvite = false
            presentError(error)
        }
    }

    /// Second step of joining: the new parent sets their name and color.
    func completeJoin(myName: String, colorHex: String) async -> Bool {
        do {
            let record = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName)
            record["nameB"] = myName
            record["colorB"] = colorHex
            try await service.save(records: [record])

            if var updated = family {
                updated.nameB = myName
                updated.colorB = colorHex
                family = updated
            }
            markSetupComplete(role: .parentB, zoneOwnerName: service.zoneID.ownerName)
            joinNeedsProfile = false
            UserDefaults.standard.set(false, forKey: Keys.joinNeedsProfile)

            await finishSetupSideEffects()
            phase = .ready
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    private func markSetupComplete(role: ParentRole, zoneOwnerName: String?) {
        setupComplete = true
        hasZoneAccess = true
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.setupComplete)
        defaults.set(role.rawValue, forKey: Keys.role)
        if let zoneOwnerName {
            defaults.set(zoneOwnerName, forKey: Keys.zoneOwnerName)
        }
    }

    private func finishSetupSideEffects() async {
        try? await service.saveSubscriptions()
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Refresh

    func refresh(silent: Bool = false) async {
        guard hasZoneAccess, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let changes = try await service.fetchZoneChanges(since: changeToken)
            let previousStatuses = storedRequestStatuses()
            apply(changes)
            changeToken = changes.changeToken
            lastSyncedAt = Date()
            saveCache()
            notifyAboutRequestChanges(previousStatuses: previousStatuses)
        } catch let error as CKError where error.code == .changeTokenExpired {
            changeToken = nil
            assignments = [:]
            notes = [:]
            requests = []
            await refresh(silent: silent)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            handleZoneGone()
        } catch {
            if !silent { presentError(error) }
        }
    }

    private func apply(_ changes: CloudKitService.ZoneChanges) {
        for record in changes.changedRecords {
            if let share = record as? CKShare {
                if myRole == .parentA, let url = share.url {
                    shareURL = url
                    UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL)
                }
                continue
            }
            switch record.recordType {
            case RecordType.family:
                if let value = Family(record: record) { family = value }
            case RecordType.dayAssignment:
                if let value = DayAssignment(record: record) { assignments[value.dateKey] = value.owner }
            case RecordType.changeRequest:
                if let value = ChangeRequest(record: record) { upsert(value) }
            case RecordType.dayNote:
                if let value = DayNote(record: record) { notes[value.dateKey] = value.text }
            default:
                break
            }
        }
        for (recordID, recordType) in changes.deletedRecordIDs {
            let name = recordID.recordName
            switch recordType {
            case RecordType.dayAssignment:
                if name.hasPrefix("day-") { assignments.removeValue(forKey: String(name.dropFirst(4))) }
            case RecordType.dayNote:
                if name.hasPrefix("note-") { notes.removeValue(forKey: String(name.dropFirst(5))) }
            case RecordType.changeRequest:
                requests.removeAll { $0.id == name }
            default:
                break
            }
        }
        requests.sort { $0.createdAt > $1.createdAt }
    }

    private func upsert(_ request: ChangeRequest) {
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests[index] = request
        } else {
            requests.append(request)
        }
    }

    private func handleZoneGone() {
        resetLocalState()
        alert = AppAlert(
            title: String(localized: "Calendar unavailable"),
            message: String(localized: "The shared calendar was deleted or your access was removed. You can create a new one or join another invitation.")
        )
    }

    // MARK: - Day actions

    /// Directly assigns an *unassigned* day (initial setup). Assigned days must
    /// go through a change request instead.
    func assignDay(_ dateKey: String, to owner: ParentRole) async {
        guard assignments[dateKey] == nil else { return }
        assignments[dateKey] = owner
        do {
            let record = service.newRecord(type: RecordType.dayAssignment, name: DayAssignment.recordName(for: dateKey))
            DayAssignment(dateKey: dateKey, owner: owner).apply(to: record)
            try await service.save(records: [record])
            saveCache()
        } catch {
            assignments.removeValue(forKey: dateKey)
            presentError(error)
        }
    }

    func setNote(_ text: String, for dateKey: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = notes[dateKey]
        do {
            if trimmed.isEmpty {
                guard previous != nil else { return }
                notes.removeValue(forKey: dateKey)
                try await service.save(records: [], deleting: [service.recordID(forName: DayNote.recordName(for: dateKey))])
            } else {
                guard trimmed != previous else { return }
                notes[dateKey] = trimmed
                let record = service.newRecord(type: RecordType.dayNote, name: DayNote.recordName(for: dateKey))
                DayNote(dateKey: dateKey, text: trimmed).apply(to: record)
                try await service.save(records: [record])
            }
            saveCache()
        } catch {
            notes[dateKey] = previous
            presentError(error)
        }
    }

    // MARK: - Change requests

    func submitRequest(changes: [DayChange], message: String) async -> Bool {
        guard !changes.isEmpty else { return false }
        let request = ChangeRequest(requester: myRole, changes: changes, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            let record = service.newRecord(type: RecordType.changeRequest, name: request.id)
            request.apply(to: record)
            try await service.save(records: [record])
            upsert(request)
            requests.sort { $0.createdAt > $1.createdAt }
            rememberRequestStatus(request)
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    func approve(_ request: ChangeRequest) async {
        guard request.isPending, request.requester != myRole else { return }
        do {
            var dayRecords: [CKRecord] = []
            for change in request.changes {
                let record = service.newRecord(type: RecordType.dayAssignment, name: DayAssignment.recordName(for: change.dateKey))
                DayAssignment(dateKey: change.dateKey, owner: change.newOwner).apply(to: record)
                dayRecords.append(record)
            }
            var resolved = request
            resolved.status = .approved
            resolved.resolvedAt = Date()
            let requestRecord = service.newRecord(type: RecordType.changeRequest, name: request.id)
            resolved.apply(to: requestRecord)

            // CloudKit caps operations at 400 records; save days in chunks,
            // and the status update last so approval is never recorded
            // before the day changes are.
            for chunk in dayRecords.chunked(into: 200) {
                try await service.save(records: chunk)
            }
            try await service.save(records: [requestRecord])

            for change in request.changes {
                assignments[change.dateKey] = change.newOwner
            }
            upsert(resolved)
            rememberRequestStatus(resolved)
            saveCache()
        } catch {
            presentError(error)
        }
    }

    func decline(_ request: ChangeRequest) async {
        guard request.isPending, request.requester != myRole else { return }
        await resolve(request, as: .declined)
    }

    func cancel(_ request: ChangeRequest) async {
        guard request.isPending, request.requester == myRole else { return }
        await resolve(request, as: .cancelled)
    }

    private func resolve(_ request: ChangeRequest, as status: ChangeRequest.Status) async {
        do {
            var resolved = request
            resolved.status = status
            resolved.resolvedAt = Date()
            let record = service.newRecord(type: RecordType.changeRequest, name: request.id)
            resolved.apply(to: record)
            try await service.save(records: [record])
            upsert(resolved)
            rememberRequestStatus(resolved)
            saveCache()
        } catch {
            presentError(error)
        }
    }

    // MARK: - Patterns

    struct PatternOutcome {
        var assignedDirectly: Int
        var sentForApproval: Int
    }

    /// Applies a generated schedule: unassigned days are set immediately;
    /// days that would change hands become one approval request.
    func applyPattern(_ proposal: [String: ParentRole]) async -> PatternOutcome? {
        var directRecords: [CKRecord] = []
        var directKeys: [String: ParentRole] = [:]
        var needsApproval: [DayChange] = []

        for (dateKey, owner) in proposal.sorted(by: { $0.key < $1.key }) {
            let current = assignments[dateKey]
            if current == owner { continue }
            if current == nil {
                let record = service.newRecord(type: RecordType.dayAssignment, name: DayAssignment.recordName(for: dateKey))
                DayAssignment(dateKey: dateKey, owner: owner).apply(to: record)
                directRecords.append(record)
                directKeys[dateKey] = owner
            } else {
                needsApproval.append(DayChange(dateKey: dateKey, newOwner: owner))
            }
        }

        do {
            for chunk in directRecords.chunked(into: 200) {
                try await service.save(records: chunk)
            }
            for (key, owner) in directKeys {
                assignments[key] = owner
            }
            if !needsApproval.isEmpty {
                let message = String(localized: "Schedule pattern update")
                let sent = await submitRequest(changes: needsApproval, message: message)
                if !sent { return nil }
            }
            saveCache()
            return PatternOutcome(assignedDirectly: directKeys.count, sentForApproval: needsApproval.count)
        } catch {
            presentError(error)
            return nil
        }
    }

    // MARK: - Settings actions

    func updateProfile(childName: String, myName: String, myColorHex: String) async {
        guard var updated = family else { return }
        do {
            let record = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName)
            record["childName"] = childName
            updated.childName = childName
            if myRole == .parentA {
                record["nameA"] = myName
                record["colorA"] = myColorHex
                updated.nameA = myName
                updated.colorA = myColorHex
            } else {
                record["nameB"] = myName
                record["colorB"] = myColorHex
                updated.nameB = myName
                updated.colorB = myColorHex
            }
            try await service.save(records: [record])
            family = updated
            saveCache()
        } catch {
            presentError(error)
        }
    }

    /// Owner deletes the calendar for everyone; participant just leaves it.
    func leaveFamily() async {
        do {
            try await service.deleteZone()
            resetLocalState()
        } catch {
            presentError(error)
        }
    }

    private func resetLocalState() {
        let defaults = UserDefaults.standard
        for key in [Keys.role, Keys.setupComplete, Keys.zoneOwnerName, Keys.changeToken, Keys.shareURL, Keys.requestStatuses, Keys.joinNeedsProfile] {
            defaults.removeObject(forKey: key)
        }
        try? FileManager.default.removeItem(at: Self.cacheURL)
        family = nil
        assignments = [:]
        notes = [:]
        requests = []
        shareURL = nil
        setupComplete = false
        hasZoneAccess = false
        joinNeedsProfile = false
        myRole = .parentA
        service.configure(isOwner: true, zoneOwnerName: nil)
        phase = .onboarding
    }

    // MARK: - Local notifications

    private func storedRequestStatuses() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: Keys.requestStatuses) as? [String: String]) ?? [:]
    }

    private func rememberRequestStatus(_ request: ChangeRequest) {
        var statuses = storedRequestStatuses()
        statuses[request.id] = request.status.rawValue
        UserDefaults.standard.set(statuses, forKey: Keys.requestStatuses)
    }

    private func notifyAboutRequestChanges(previousStatuses: [String: String]) {
        var statuses = previousStatuses
        for request in requests {
            let previous = previousStatuses[request.id]
            defer { statuses[request.id] = request.status.rawValue }

            if request.requester != myRole, request.isPending, previous == nil {
                let count = request.changes.count
                let body = count == 1
                    ? String(localized: "\(otherName) proposes a change for \(Day.shortLabel(for: request.changes[0].dateKey)).")
                    : String(localized: "\(otherName) proposes changes to \(count) days.")
                postLocalNotification(
                    id: "request-\(request.id)",
                    title: String(localized: "New change request"),
                    body: body
                )
            }

            if request.requester == myRole, previous == ChangeRequest.Status.pending.rawValue, !request.isPending, request.status != .cancelled {
                let title = request.status == .approved
                    ? String(localized: "Request approved 🎉")
                    : String(localized: "Request declined")
                let body = request.status == .approved
                    ? String(localized: "\(otherName) approved your schedule change.")
                    : String(localized: "\(otherName) declined your schedule change.")
                postLocalNotification(id: "resolved-\(request.id)", title: title, body: body)
            }
        }
        UserDefaults.standard.set(statuses, forKey: Keys.requestStatuses)
    }

    private func postLocalNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Change token persistence

    private var changeToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.changeToken) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            let defaults = UserDefaults.standard
            if let newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Keys.changeToken)
            } else {
                defaults.removeObject(forKey: Keys.changeToken)
            }
        }
    }

    // MARK: - Offline cache

    private struct CachePayload: Codable {
        var family: Family?
        var assignments: [String: ParentRole]
        var notes: [String: String]
        var requests: [ChangeRequest]
    }

    private static var cacheURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("nido-cache.json")
    }

    private func saveCache() {
        let payload = CachePayload(family: family, assignments: assignments, notes: notes, requests: requests)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data)
        else { return }
        family = payload.family
        assignments = payload.assignments
        notes = payload.notes
        requests = payload.requests
    }

    // MARK: - Errors

    private func presentError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                alert = AppAlert(
                    title: String(localized: "No connection"),
                    message: String(localized: "Your change couldn't be saved. Please check your internet connection and try again.")
                )
                return
            case .notAuthenticated:
                alert = AppAlert(
                    title: String(localized: "iCloud needed"),
                    message: String(localized: "Please sign in to iCloud in the iPhone Settings app to keep the calendar in sync.")
                )
                return
            case .quotaExceeded:
                alert = AppAlert(
                    title: String(localized: "iCloud storage full"),
                    message: String(localized: "Your iCloud storage is full, so changes can't be saved right now.")
                )
                return
            default:
                break
            }
        }
        alert = AppAlert(
            title: String(localized: "Something went wrong"),
            message: error.localizedDescription
        )
    }
}

// MARK: - Helpers

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
