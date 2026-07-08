import CloudKit
import Foundation
import Observation
import UserNotifications

/// Central app state. One person can belong to SEVERAL families — each
/// family is one co-parenting relationship (a different ex), fully isolated
/// in its own CloudKit zone with its own members, days, notes and requests.
/// All the user's children & pets appear together in one member list; every
/// action resolves to the right family (and the right co-parent) through
/// the member or request it concerns.
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

    /// Everything a view needs to act on one member's calendar.
    struct MemberContext {
        var member: Member
        var familyID: String
        var family: Family
        var myRole: ParentRole
        var partnerJoined: Bool

        var otherRole: ParentRole { myRole.other }
        var myName: String { family.name(of: myRole) }
        var otherName: String { family.name(of: otherRole) }
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .loading
    private(set) var familyRefs: [FamilyRef] = []
    /// familyID → parent profile (names + colors)
    private(set) var families: [String: Family] = [:]
    private(set) var membersByID: [String: Member] = [:]
    /// memberID → familyID
    private(set) var memberFamily: [String: String] = [:]
    private(set) var memberOrder: [String] = []
    /// memberID → dateKey → owner
    private(set) var assignments: [String: [String: ParentRole]] = [:]
    /// memberID → dateKey → who set it directly (absent = locked/approved)
    private(set) var directAssigner: [String: [String: ParentRole]] = [:]
    /// memberID → dateKey → note text
    private(set) var notes: [String: [String: String]] = [:]
    private(set) var requests: [ChangeRequest] = []
    /// memberID → date keys inside pending requests
    private(set) var pendingDateKeys: [String: Set<String>] = [:]
    /// familyID → invitation URL (owned families only)
    private(set) var shareURLs: [String: URL] = [:]
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    var selectedMemberID: String? {
        didSet {
            if let selectedMemberID {
                UserDefaults.standard.set(selectedMemberID, forKey: Keys.selectedMember)
            }
        }
    }

    /// Set while a joined family still needs my name/color.
    private(set) var pendingJoinFamilyID: String?
    var isAcceptingInvite = false

    var alert: AppAlert?

    // MARK: - Derived state

    var members: [Member] { memberOrder.compactMap { membersByID[$0] } }

    var joinNeedsProfile: Bool { pendingJoinFamilyID != nil }

    func member(_ id: String) -> Member? { membersByID[id] }

    var selectedMember: Member? {
        if let selectedMemberID, let member = membersByID[selectedMemberID] { return member }
        return members.first
    }

    func family(_ familyID: String) -> Family? { families[familyID] }

    func ref(_ familyID: String) -> FamilyRef? { familyRefs.first { $0.id == familyID } }

    func myRole(in familyID: String) -> ParentRole { ref(familyID)?.role ?? .parentA }

    func familyID(ofMember memberID: String) -> String? { memberFamily[memberID] }

    func context(_ memberID: String) -> MemberContext? {
        guard let member = membersByID[memberID],
              let familyID = memberFamily[memberID],
              let family = families[familyID]
        else { return nil }
        return MemberContext(
            member: member,
            familyID: familyID,
            family: family,
            myRole: myRole(in: familyID),
            partnerJoined: family.partnerHasJoined
        )
    }

    /// Family the pending join belongs to (for the join-profile screen).
    var pendingJoinFamily: Family? {
        guard let pendingJoinFamilyID else { return nil }
        return families[pendingJoinFamilyID]
    }

    func membersOf(_ familyID: String) -> [Member] {
        members.filter { memberFamily[$0.id] == familyID }
    }

    func shareURL(for familyID: String) -> URL? { shareURLs[familyID] }

    func owner(of memberID: String, on dateKey: String) -> ParentRole? {
        assignments[memberID]?[dateKey]
    }

    func note(of memberID: String, on dateKey: String) -> String? {
        notes[memberID]?[dateKey]
    }

    func isPending(_ memberID: String, _ dateKey: String) -> Bool {
        pendingDateKeys[memberID]?.contains(dateKey) ?? false
    }

    var pendingIncoming: [ChangeRequest] {
        requests.filter { $0.isPending && $0.requester != myRole(in: $0.familyID) }
    }
    var pendingOutgoing: [ChangeRequest] {
        requests.filter { $0.isPending && $0.requester == myRole(in: $0.familyID) }
    }
    var resolvedRequests: [ChangeRequest] {
        requests.filter { !$0.isPending }.sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
    }

    /// Names for a request's two sides, resolved through its family.
    func requesterName(of request: ChangeRequest) -> String {
        families[request.familyID]?.name(of: request.requester) ?? String(localized: "Co-parent")
    }
    func otherPartyName(of request: ChangeRequest) -> String {
        families[request.familyID]?.name(of: myRole(in: request.familyID).other) ?? String(localized: "Co-parent")
    }

    /// Whether a member's day can be set to `newOwner` (nil = cleared)
    /// without that family's co-parent approval. Per family:
    /// - a day inside a pending request is never directly editable;
    /// - an unassigned day can be recorded freely by either parent;
    /// - a day directly recorded for me stays mine to adjust (keep/clear),
    ///   but handing it to the other parent needs approval;
    /// - days recorded for the other parent or agreed through a request
    ///   only change via approval.
    /// While that family's co-parent hasn't joined, everything is editable.
    func canEditDirectly(_ memberID: String, _ dateKey: String, settingTo newOwner: ParentRole?) -> Bool {
        guard let ctx = context(memberID) else { return false }
        guard !isPending(memberID, dateKey) else { return false }
        if !ctx.partnerJoined { return true }
        if owner(of: memberID, on: dateKey) == nil { return true }
        guard directAssigner[memberID]?[dateKey] == ctx.myRole else { return false }
        return newOwner != ctx.otherRole
    }

    // MARK: - Private

    private var service = CloudKitService()

    private enum Keys {
        static let familyRefs = "nido.familyRefs"
        static let requestStatuses = "nido.requestStatuses"
        static let selectedMember = "nido.selectedMember"
        static func changeToken(_ familyID: String) -> String { "nido.changeToken.\(familyID)" }
        static func shareURL(_ familyID: String) -> String { "nido.shareURL.\(familyID)" }
        static func shareLocked(_ familyID: String) -> String { "nido.shareLocked.\(familyID)" }
    }

    init() {
        selectedMemberID = UserDefaults.standard.string(forKey: Keys.selectedMember)
        familyRefs = Self.loadRefs()
    }

    private static func loadRefs() -> [FamilyRef] {
        guard let data = UserDefaults.standard.data(forKey: Keys.familyRefs),
              let refs = try? JSONDecoder().decode([FamilyRef].self, from: data)
        else { return [] }
        return refs
    }

    private func persistRefs() {
        if let data = try? JSONEncoder().encode(familyRefs) {
            UserDefaults.standard.set(data, forKey: Keys.familyRefs)
        }
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard phase == .loading else { return }
        if familyRefs.isEmpty {
            phase = .onboarding
            return
        }
        loadCache()
        // A family whose profile step never finished resumes the join flow.
        if let incomplete = familyRefs.first(where: { !isProfileComplete($0) }), familyRefs.count == 1 {
            pendingJoinFamilyID = incomplete.id
            phase = .onboarding
        } else {
            if let incomplete = familyRefs.first(where: { !isProfileComplete($0) }) {
                pendingJoinFamilyID = incomplete.id
            }
            phase = .ready
        }
        await refresh(silent: true)
    }

    /// My side of the profile is filled in for this family.
    private func isProfileComplete(_ ref: FamilyRef) -> Bool {
        guard let family = families[ref.id] else { return ref.role == .parentA }
        let mine = ref.role == .parentA ? family.nameA : family.nameB
        return !mine.trimmingCharacters(in: .whitespaces).isEmpty
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

    // MARK: - Create a family (works for the first one and for additional exes)

    @discardableResult
    func createFamily(myName: String, firstMemberName: String, firstMemberKind: Member.Kind, colorHex: String) async -> String? {
        guard await checkAccountStatus() else { return nil }
        do {
            let zoneName = FamilyRef.newZoneName()
            let ref = FamilyRef(role: .parentA, zoneName: zoneName, zoneOwnerName: nil)
            let handle = service.handle(for: ref)

            let shareTitle = String(localized: "Custody calendar for \(firstMemberName)")
            let url = try await service.createZoneAndShare(zoneName: zoneName, title: shareTitle)

            var newFamily = Family(nameA: myName, colorA: colorHex)
            if colorHex == newFamily.colorB {
                newFamily.colorB = Palette.options.first { $0 != colorHex } ?? Palette.defaultB
            }
            let familyRecord = service.newRecord(type: RecordType.family, name: Family.recordName, in: handle)
            newFamily.apply(to: familyRecord)

            let firstMember = Member(name: firstMemberName, kind: firstMemberKind, sortOrder: 0)
            let memberRecord = service.newRecord(type: RecordType.member, name: firstMember.id, in: handle)
            firstMember.apply(to: memberRecord)

            try await service.save(records: [familyRecord, memberRecord], in: handle)

            familyRefs.append(ref)
            persistRefs()
            families[ref.id] = newFamily
            membersByID[firstMember.id] = firstMember
            memberFamily[firstMember.id] = ref.id
            rebuildDerived()
            selectedMemberID = firstMember.id
            shareURLs[ref.id] = url
            UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL(ref.id))

            await finishSetupSideEffects()
            saveCache()
            Task { await refresh(silent: true) }
            return ref.id
        } catch {
            presentError(error)
            return nil
        }
    }

    /// Moves from onboarding into the main app (used after the invite screen).
    func enterApp() {
        phase = .ready
    }

    /// Recovers every existing calendar after a reinstall or new phone:
    /// owned zones and zones shared with us.
    func reconnectExistingCalendar() async -> Bool {
        guard await checkAccountStatus() else { return false }
        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        let owned: [CKRecordZone]
        let shared: [CKRecordZone]
        do {
            (owned, shared) = try await service.listFamilyZones()
        } catch {
            presentError(error)
            return false
        }

        var restored: [FamilyRef] = []
        for zone in owned {
            restored.append(FamilyRef(role: .parentA, zoneName: zone.zoneID.zoneName, zoneOwnerName: nil))
        }
        for zone in shared {
            restored.append(FamilyRef(role: .parentB, zoneName: zone.zoneID.zoneName, zoneOwnerName: zone.zoneID.ownerName))
        }
        guard !restored.isEmpty else {
            alert = AppAlert(
                title: String(localized: "Nothing to restore"),
                message: String(localized: "No calendar was found on this iCloud account. You can create a new one or join with an invitation.")
            )
            return false
        }

        for ref in restored where self.ref(ref.id) == nil {
            familyRefs.append(ref)
            UserDefaults.standard.removeObject(forKey: Keys.changeToken(ref.id))
        }
        persistRefs()

        let synced = await refresh(silent: true)
        if !synced && families.isEmpty {
            // Zones exist but couldn't be loaded — a transient failure must
            // not read as "nothing to restore".
            familyRefs.removeAll { candidate in restored.contains { $0.id == candidate.id } && families[candidate.id] == nil }
            persistRefs()
            alert = AppAlert(
                title: String(localized: "Couldn't reach iCloud"),
                message: String(localized: "Your calendar was found but couldn't be loaded. Please check your connection and try again.")
            )
            return false
        }

        for ref in familyRefs where ref.role == .parentA {
            if let share = try? await service.fetchShare(in: service.handle(for: ref)), let url = share.url {
                shareURLs[ref.id] = url
                UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL(ref.id))
            }
        }

        await finishSetupSideEffects()
        if let incomplete = familyRefs.first(where: { !isProfileComplete($0) }) {
            pendingJoinFamilyID = incomplete.id
            phase = familyRefs.count == 1 ? .onboarding : .ready
        } else {
            phase = .ready
        }
        saveCache()
        return true
    }

    // MARK: - Join a family (invited side)

    /// Called when iOS hands us an accepted CloudKit share, or after we
    /// accept one manually from a pasted/scanned invitation link. Adds a
    /// NEW family — existing families are untouched, so custody with a
    /// different ex can live side by side.
    func handleIncomingShare(_ metadata: CKShare.Metadata) async {
        guard await checkAccountStatus() else { return }
        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        let zoneID = metadata.share.recordID.zoneID
        let incomingRef = FamilyRef(role: .parentB, zoneName: zoneID.zoneName, zoneOwnerName: zoneID.ownerName)

        // Tapping an invitation for a family we're already part of is just
        // a rejoin of that one family.
        if let existing = ref(incomingRef.id) {
            await refresh(silent: true)
            if isProfileComplete(existing) {
                phase = .ready
            } else {
                pendingJoinFamilyID = existing.id
                if familyRefs.count == 1 { phase = .onboarding }
            }
            return
        }

        // One co-parent per family: refuse if someone else already accepted
        // this invitation (rejoins by this iCloud account are allowed).
        let isRejoin = metadata.participantStatus == .accepted
        if !isRejoin {
            let someoneElseJoined = metadata.share.participants.contains {
                $0.role != .owner && $0.acceptanceStatus == .accepted
            }
            if someoneElseJoined {
                alert = Self.invitationUsedAlert
                return
            }
        }

        do {
            try await service.acceptShare(metadata: metadata)
        } catch {
            // The share may already be accepted (e.g. tapping the link
            // twice). If we can reach the zone anyway, carry on.
            let probe = await probeFamily(incomingRef)
            if !probe {
                presentError(error)
                return
            }
        }

        familyRefs.append(incomingRef)
        persistRefs()
        UserDefaults.standard.removeObject(forKey: Keys.changeToken(incomingRef.id))
        await refresh(silent: true)

        guard let joined = families[incomingRef.id] else {
            // Couldn't load the new family — back out cleanly.
            removeFamilyLocally(incomingRef.id)
            alert = AppAlert(
                title: String(localized: "Couldn't reach iCloud"),
                message: String(localized: "Your calendar was found but couldn't be loaded. Please check your connection and try again.")
            )
            return
        }

        // Second line of defense: the profile slot is already taken and this
        // iCloud account isn't the one that joined — leave the share again.
        if !isRejoin, joined.partnerHasJoined {
            try? await service.deleteZone(in: service.handle(for: incomingRef))
            removeFamilyLocally(incomingRef.id)
            alert = Self.invitationUsedAlert
            return
        }

        await finishSetupSideEffects()

        // Rejoin with a completed profile (reinstall / new phone): straight
        // back to the calendar.
        if isRejoin, joined.partnerHasJoined {
            saveCache()
            phase = .ready
            return
        }

        pendingJoinFamilyID = incomingRef.id
        if phase != .ready { phase = .onboarding }
        saveCache()
    }

    /// True if the family's zone is reachable (used to recover from
    /// "already accepted" errors).
    private func probeFamily(_ ref: FamilyRef) async -> Bool {
        let handle = service.handle(for: ref)
        return (try? await service.fetchZoneChanges(in: handle, since: nil)) != nil
    }

    private static var invitationUsedAlert: AppAlert {
        AppAlert(
            title: String(localized: "Invitation already used"),
            message: String(localized: "Another person has already joined this calendar with that invitation. Ask the calendar's creator to check their sharing settings.")
        )
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

    /// Second step of joining: the invited parent sets their name and color
    /// for the family they just joined.
    func completeJoin(myName: String, colorHex: String) async -> Bool {
        guard let familyID = pendingJoinFamilyID, let joinRef = ref(familyID) else { return false }
        let handle = service.handle(for: joinRef)
        do {
            let record = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName, in: handle)
            // Last line of defense against two people racing one invitation:
            // if someone else completed the join first, back out.
            if let taken = record["nameB"] as? String,
               !taken.trimmingCharacters(in: .whitespaces).isEmpty {
                try? await service.deleteZone(in: handle)
                removeFamilyLocally(familyID)
                pendingJoinFamilyID = nil
                if familyRefs.isEmpty { phase = .onboarding }
                alert = Self.invitationUsedAlert
                return false
            }
            record["nameB"] = myName
            record["colorB"] = colorHex
            try await service.save(records: [record], in: handle)

            if var updated = families[familyID] {
                updated.nameB = myName
                updated.colorB = colorHex
                families[familyID] = updated
            }
            pendingJoinFamilyID = nil
            if selectedMember == nil || memberFamily[selectedMemberID ?? ""] == nil {
                selectedMemberID = membersOf(familyID).first?.id ?? members.first?.id
            }
            await finishSetupSideEffects()
            phase = .ready
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    private func finishSetupSideEffects() async {
        for ref in familyRefs where ref.role == .parentA {
            try? await service.saveZoneSubscription(zoneName: ref.zoneName)
        }
        if familyRefs.contains(where: { $0.role == .parentB }) {
            try? await service.saveSharedDatabaseSubscription()
        }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Members (children & pets)

    @discardableResult
    func addMember(familyID: String, name: String, kind: Member.Kind) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let familyRef = ref(familyID),
              membersOf(familyID).count < Member.maxCount
        else { return false }
        let handle = service.handle(for: familyRef)
        let maxOrder = membersOf(familyID).map(\.sortOrder).max() ?? -1
        let member = Member(name: trimmed, kind: kind, sortOrder: maxOrder + 1)
        do {
            let record = service.newRecord(type: RecordType.member, name: member.id, in: handle)
            member.apply(to: record)
            try await service.save(records: [record], in: handle)
            membersByID[member.id] = member
            memberFamily[member.id] = familyID
            rebuildDerived()
            if selectedMemberID == nil { selectedMemberID = member.id }
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    func renameMember(_ memberID: String, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              var member = membersByID[memberID],
              member.name != trimmed,
              let familyID = memberFamily[memberID],
              let familyRef = ref(familyID)
        else { return }
        do {
            let handle = service.handle(for: familyRef)
            let record = service.newRecord(type: RecordType.member, name: memberID, in: handle)
            member.name = trimmed
            member.apply(to: record)
            try await service.save(records: [record], in: handle)
            membersByID[memberID] = member
            rebuildDerived()
            saveCache()
        } catch {
            presentError(error)
        }
    }

    /// Fixing a mis-tapped child/pet choice shouldn't require deleting the
    /// whole calendar — the kind is presentational (icon + wording).
    func setMemberKind(_ memberID: String, to kind: Member.Kind) async {
        guard var member = membersByID[memberID],
              member.kind != kind,
              let familyID = memberFamily[memberID],
              let familyRef = ref(familyID)
        else { return }
        do {
            let handle = service.handle(for: familyRef)
            let record = service.newRecord(type: RecordType.member, name: memberID, in: handle)
            member.kind = kind
            member.apply(to: record)
            try await service.save(records: [record], in: handle)
            membersByID[memberID] = member
            saveCache()
        } catch {
            presentError(error)
        }
    }

    /// Removes a member and every record of theirs (days, notes) plus their
    /// pending requests. A family's last member can't be deleted. The member
    /// record and the request cancellations go in ONE atomic operation, so a
    /// crash mid-way can never leave ghost pending requests; day/note
    /// deletions follow (orphans are also pruned defensively in `apply`).
    func deleteMember(_ memberID: String) async {
        guard let familyID = memberFamily[memberID],
              let familyRef = ref(familyID),
              membersOf(familyID).count > 1
        else { return }
        let handle = service.handle(for: familyRef)
        do {
            var cancelled: [ChangeRequest] = []
            var cancelRecords: [CKRecord] = []
            for request in requests where request.isPending && request.memberID == memberID {
                var resolved = request
                resolved.status = .cancelled
                resolved.resolvedAt = Date()
                let record = service.newRecord(type: RecordType.changeRequest, name: request.id, in: handle)
                resolved.apply(to: record)
                cancelRecords.append(record)
                cancelled.append(resolved)
            }

            try await service.save(records: cancelRecords, deleting: [service.recordID(forName: memberID, in: handle)], in: handle)

            var dayNoteIDs: [CKRecord.ID] = []
            for dateKey in (assignments[memberID] ?? [:]).keys {
                dayNoteIDs.append(service.recordID(forName: DayAssignment.recordName(member: memberID, dateKey: dateKey), in: handle))
            }
            for dateKey in (notes[memberID] ?? [:]).keys {
                dayNoteIDs.append(service.recordID(forName: DayNote.recordName(member: memberID, dateKey: dateKey), in: handle))
            }
            for chunk in dayNoteIDs.chunked(into: 200) {
                try await service.save(records: [], deleting: chunk, in: handle)
            }

            membersByID.removeValue(forKey: memberID)
            memberFamily.removeValue(forKey: memberID)
            assignments.removeValue(forKey: memberID)
            directAssigner.removeValue(forKey: memberID)
            notes.removeValue(forKey: memberID)
            for request in cancelled {
                upsert(request)
                rememberRequestStatus(request)
            }
            rebuildDerived()
            if selectedMemberID == memberID { selectedMemberID = members.first?.id }
            saveCache()
        } catch {
            presentError(error)
        }
    }

    // MARK: - Refresh

    @discardableResult
    func refresh(silent: Bool = false) async -> Bool {
        guard !familyRefs.isEmpty, !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        let previousStatuses = storedRequestStatuses()
        var outcomes: [(familyID: String, outcome: ApplyOutcome)] = []
        var partnerWasJoined: [String: Bool] = [:]
        var anyInitialSync = false
        var allOK = true

        for familyRef in familyRefs {
            partnerWasJoined[familyRef.id] = families[familyRef.id]?.partnerHasJoined == true
            let result = await refreshFamily(familyRef, silent: silent)
            switch result {
            case .success(let outcome, let wasInitial):
                outcomes.append((familyRef.id, outcome))
                if wasInitial { anyInitialSync = true }
            case .gone:
                allOK = false
            case .failed:
                allOK = false
            }
        }

        lastSyncedAt = Date()
        rebuildDerived()
        saveCache()
        if anyInitialSync && previousStatuses.isEmpty {
            // First sync on this device: record state without a
            // notification storm for pre-existing requests.
            recordAllRequestStatuses()
        } else {
            notifyAboutChanges(
                previousStatuses: previousStatuses,
                outcomes: outcomes,
                partnerWasJoined: partnerWasJoined
            )
        }
        await lockSharesIfNeeded()
        return allOK
    }

    private enum FamilyRefreshResult {
        case success(ApplyOutcome, wasInitialSync: Bool)
        case gone
        case failed
    }

    private func refreshFamily(_ familyRef: FamilyRef, silent: Bool) async -> FamilyRefreshResult {
        let handle = service.handle(for: familyRef)
        var retriedAfterTokenReset = false
        while true {
            let token = changeToken(for: familyRef.id)
            let isInitialSync = token == nil
            do {
                let changes = try await service.fetchZoneChanges(in: handle, since: token)
                let outcome = apply(changes, familyID: familyRef.id)
                if let newToken = changes.changeToken {
                    setChangeToken(newToken, for: familyRef.id)
                }
                return .success(outcome, wasInitialSync: isInitialSync)
            } catch {
                let code = Self.normalizedCKErrorCode(error)
                if code == .changeTokenExpired, !retriedAfterTokenReset {
                    retriedAfterTokenReset = true
                    setChangeToken(nil, for: familyRef.id)
                    clearFamilyData(familyRef.id)
                    continue
                }
                if code == .zoneNotFound || code == .userDeletedZone {
                    handleFamilyGone(familyRef)
                    return .gone
                }
                if !silent { presentError(error) }
                return .failed
            }
        }
    }

    /// Once a family's co-parent has joined, kill that invitation link at
    /// the platform level so nobody else can use it. Owner side, once each.
    private func lockSharesIfNeeded() async {
        for familyRef in familyRefs where familyRef.role == .parentA {
            guard families[familyRef.id]?.partnerHasJoined == true,
                  !UserDefaults.standard.bool(forKey: Keys.shareLocked(familyRef.id))
            else { continue }
            let handle = service.handle(for: familyRef)
            guard let share = try? await service.fetchShare(in: handle) else { continue }
            if share.publicPermission != .none {
                share.publicPermission = .none
                guard (try? await service.save(records: [share], in: handle)) != nil else { continue }
            }
            UserDefaults.standard.set(true, forKey: Keys.shareLocked(familyRef.id))
        }
    }

    /// Zone-level CloudKit errors sometimes arrive wrapped in a partialFailure.
    private static func normalizedCKErrorCode(_ error: Error) -> CKError.Code? {
        guard let ckError = error as? CKError else { return nil }
        if ckError.code == .partialFailure {
            let inner = ckError.partialErrorsByItemID?.values.compactMap { $0 as? CKError }.first
            return inner?.code ?? ckError.code
        }
        return ckError.code
    }

    struct ApplyOutcome {
        /// "memberID|dateKey" keys whose assignment changed remotely.
        var changedDays: Set<String> = []
        var deletedMembers: [(name: String, dayCount: Int)] = []
        var addedMemberNames: [String] = []
    }

    private func apply(_ changes: CloudKitService.ZoneChanges, familyID: String) -> ApplyOutcome {
        var outcome = ApplyOutcome()
        for record in changes.changedRecords {
            if let share = record as? CKShare {
                if myRole(in: familyID) == .parentA, let url = share.url {
                    shareURLs[familyID] = url
                    UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL(familyID))
                }
                continue
            }
            switch record.recordType {
            case RecordType.family:
                if let value = Family(record: record) { families[familyID] = value }
            case RecordType.member:
                if let value = Member(record: record) {
                    if membersByID[value.id] == nil {
                        outcome.addedMemberNames.append(value.name)
                    }
                    membersByID[value.id] = value
                    memberFamily[value.id] = familyID
                }
            case RecordType.dayAssignment:
                if let value = DayAssignment(record: record) {
                    if assignments[value.memberID]?[value.dateKey] != value.owner {
                        outcome.changedDays.insert(value.memberID + "|" + value.dateKey)
                    }
                    assignments[value.memberID, default: [:]][value.dateKey] = value.owner
                    directAssigner[value.memberID, default: [:]][value.dateKey] = value.assignedBy
                }
            case RecordType.changeRequest:
                if var value = ChangeRequest(record: record) {
                    value.familyID = familyID
                    upsert(value)
                }
            case RecordType.dayNote:
                if let value = DayNote(record: record) {
                    notes[value.memberID, default: [:]][value.dateKey] = value.text
                }
            default:
                break
            }
        }
        for (recordID, recordType) in changes.deletedRecordIDs {
            let name = recordID.recordName
            switch recordType {
            case RecordType.member:
                // A removed member must never look like ordinary day edits:
                // capture the loss for its own loud notification and scrub
                // their day-change entries.
                if let existing = membersByID[name] {
                    outcome.deletedMembers.append((existing.name, assignments[name]?.count ?? 0))
                }
                membersByID.removeValue(forKey: name)
                memberFamily.removeValue(forKey: name)
                assignments.removeValue(forKey: name)
                directAssigner.removeValue(forKey: name)
                notes.removeValue(forKey: name)
                outcome.changedDays = outcome.changedDays.filter { !$0.hasPrefix(name + "|") }
                // Their pending requests are doomed (cancellation records
                // are on the way); reflect that immediately.
                for index in requests.indices
                where requests[index].memberID == name && requests[index].isPending {
                    requests[index].status = .cancelled
                    requests[index].resolvedAt = Date()
                }
            case RecordType.dayAssignment:
                if let parsed = DayAssignment.parseRecordName(name, prefix: "day-") {
                    if assignments[parsed.memberID]?[parsed.dateKey] != nil {
                        outcome.changedDays.insert(parsed.memberID + "|" + parsed.dateKey)
                    }
                    assignments[parsed.memberID]?.removeValue(forKey: parsed.dateKey)
                    directAssigner[parsed.memberID]?.removeValue(forKey: parsed.dateKey)
                }
            case RecordType.dayNote:
                if let parsed = DayAssignment.parseRecordName(name, prefix: "note-") {
                    notes[parsed.memberID]?.removeValue(forKey: parsed.dateKey)
                }
            case RecordType.changeRequest:
                requests.removeAll { $0.id == name }
            default:
                break
            }
        }
        // Defensive orphan pruning: day/note records whose member no longer
        // exists (e.g. a deletion that crashed halfway on the other device)
        // must not haunt the caches.
        if !membersByID.isEmpty {
            let ids = Set(membersByID.keys)
            assignments = assignments.filter { ids.contains($0.key) }
            directAssigner = directAssigner.filter { ids.contains($0.key) }
            notes = notes.filter { ids.contains($0.key) }
        }
        return outcome
    }

    /// Rebuilds display order (family order, then member sort order) and
    /// pending-day sets; heals a stale member selection.
    private func rebuildDerived() {
        var order: [String] = []
        for familyRef in familyRefs {
            let familyMembers = membersByID.values
                .filter { memberFamily[$0.id] == familyRef.id }
                .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            order.append(contentsOf: familyMembers.map(\.id))
        }
        memberOrder = order
        requests.sort { $0.createdAt > $1.createdAt }
        var keys: [String: Set<String>] = [:]
        for request in requests where request.isPending {
            keys[request.memberID, default: []].formUnion(request.changes.map(\.dateKey))
        }
        pendingDateKeys = keys
        if selectedMemberID == nil || membersByID[selectedMemberID ?? ""] == nil {
            selectedMemberID = memberOrder.first
        }
    }

    private func upsert(_ request: ChangeRequest) {
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            var merged = request
            if merged.familyID.isEmpty { merged.familyID = requests[index].familyID }
            requests[index] = merged
        } else {
            requests.append(request)
        }
    }

    /// A family's zone disappeared (deleted, or our access was revoked):
    /// drop just that family; the others keep working.
    private func handleFamilyGone(_ familyRef: FamilyRef) {
        let name = families[familyRef.id]?.name(of: familyRef.role.other) ?? String(localized: "Co-parent")
        removeFamilyLocally(familyRef.id)
        alert = AppAlert(
            title: String(localized: "Calendar unavailable"),
            message: String(localized: "The calendar you share with \(name) was deleted or your access was removed.")
        )
    }

    private func removeFamilyLocally(_ familyID: String) {
        familyRefs.removeAll { $0.id == familyID }
        persistRefs()
        families.removeValue(forKey: familyID)
        let gone = memberFamily.filter { $0.value == familyID }.map(\.key)
        for memberID in gone {
            membersByID.removeValue(forKey: memberID)
            memberFamily.removeValue(forKey: memberID)
            assignments.removeValue(forKey: memberID)
            directAssigner.removeValue(forKey: memberID)
            notes.removeValue(forKey: memberID)
        }
        requests.removeAll { $0.familyID == familyID }
        shareURLs.removeValue(forKey: familyID)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.changeToken(familyID))
        defaults.removeObject(forKey: Keys.shareURL(familyID))
        defaults.removeObject(forKey: Keys.shareLocked(familyID))
        if pendingJoinFamilyID == familyID { pendingJoinFamilyID = nil }
        rebuildDerived()
        saveCache()
        if familyRefs.isEmpty {
            phase = .onboarding
        }
    }

    private func clearFamilyData(_ familyID: String) {
        families.removeValue(forKey: familyID)
        let gone = memberFamily.filter { $0.value == familyID }.map(\.key)
        for memberID in gone {
            membersByID.removeValue(forKey: memberID)
            memberFamily.removeValue(forKey: memberID)
            assignments.removeValue(forKey: memberID)
            directAssigner.removeValue(forKey: memberID)
            notes.removeValue(forKey: memberID)
        }
        requests.removeAll { $0.familyID == familyID }
        rebuildDerived()
    }

    // MARK: - Day actions

    /// Directly sets or clears a member's day, when allowed (see
    /// `canEditDirectly`). Editability follows the day: a direct assignment
    /// is stamped with the *receiving* parent.
    func setDayDirectly(_ memberID: String, _ dateKey: String, to newOwner: ParentRole?) async {
        guard canEditDirectly(memberID, dateKey, settingTo: newOwner),
              let familyID = memberFamily[memberID],
              let familyRef = ref(familyID)
        else { return }
        let handle = service.handle(for: familyRef)
        let previousOwner = owner(of: memberID, on: dateKey)
        let previousAssigner = directAssigner[memberID]?[dateKey]
        guard previousOwner != newOwner else { return }

        if let newOwner {
            assignments[memberID, default: [:]][dateKey] = newOwner
            directAssigner[memberID, default: [:]][dateKey] = newOwner
        } else {
            assignments[memberID]?.removeValue(forKey: dateKey)
            directAssigner[memberID]?.removeValue(forKey: dateKey)
        }
        do {
            let recordName = DayAssignment.recordName(member: memberID, dateKey: dateKey)
            if let newOwner {
                let record = service.newRecord(type: RecordType.dayAssignment, name: recordName, in: handle)
                DayAssignment(memberID: memberID, dateKey: dateKey, owner: newOwner, assignedBy: newOwner).apply(to: record)
                try await service.save(records: [record], in: handle)
            } else {
                try await service.save(records: [], deleting: [service.recordID(forName: recordName, in: handle)], in: handle)
            }
            saveCache()
        } catch {
            if let previousOwner {
                assignments[memberID, default: [:]][dateKey] = previousOwner
                directAssigner[memberID, default: [:]][dateKey] = previousAssigner
            } else {
                assignments[memberID]?.removeValue(forKey: dateKey)
                directAssigner[memberID]?.removeValue(forKey: dateKey)
            }
            presentError(error)
        }
    }

    func setNote(_ text: String, member memberID: String, on dateKey: String) async {
        guard let familyID = memberFamily[memberID], let familyRef = ref(familyID) else { return }
        let handle = service.handle(for: familyRef)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = note(of: memberID, on: dateKey)
        do {
            let recordName = DayNote.recordName(member: memberID, dateKey: dateKey)
            if trimmed.isEmpty {
                guard previous != nil else { return }
                notes[memberID]?.removeValue(forKey: dateKey)
                try await service.save(records: [], deleting: [service.recordID(forName: recordName, in: handle)], in: handle)
            } else {
                guard trimmed != previous else { return }
                notes[memberID, default: [:]][dateKey] = trimmed
                let record = service.newRecord(type: RecordType.dayNote, name: recordName, in: handle)
                DayNote(memberID: memberID, dateKey: dateKey, text: trimmed).apply(to: record)
                try await service.save(records: [record], in: handle)
            }
            saveCache()
        } catch {
            if let previous {
                notes[memberID, default: [:]][dateKey] = previous
            } else {
                notes[memberID]?.removeValue(forKey: dateKey)
            }
            presentError(error)
        }
    }

    // MARK: - Change requests

    func submitRequest(member memberID: String, changes: [DayChange], message: String, kind: ChangeRequest.Kind = .manual) async -> Bool {
        guard !changes.isEmpty,
              let familyID = memberFamily[memberID],
              let familyRef = ref(familyID)
        else { return false }
        let handle = service.handle(for: familyRef)
        let request = ChangeRequest(
            familyID: familyID,
            memberID: memberID,
            requester: familyRef.role,
            changes: changes,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind
        )
        do {
            let record = service.newRecord(type: RecordType.changeRequest, name: request.id, in: handle)
            request.apply(to: record)
            try await service.save(records: [record], in: handle)
            upsert(request)
            rebuildDerived()
            rememberRequestStatus(request)
            saveCache()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    func approve(_ request: ChangeRequest) async {
        guard request.isPending,
              let familyRef = ref(request.familyID),
              request.requester != familyRef.role
        else { return }
        let handle = service.handle(for: familyRef)
        // Sync first so the stale-day validation below runs against the
        // freshest state we can get, not a lagging local cache.
        await refresh(silent: true)
        do {
            // Guard against the cancel-vs-approve race: confirm the request
            // is still pending on the server before applying anything.
            let serverRecord = try await handle.database.record(for: service.recordID(forName: request.id, in: handle))
            guard var serverRequest = ChangeRequest(record: serverRecord), serverRequest.isPending else {
                if var serverRequest = ChangeRequest(record: serverRecord) {
                    serverRequest.familyID = request.familyID
                    upsert(serverRequest)
                    rememberRequestStatus(serverRequest)
                }
                alert = AppAlert(
                    title: String(localized: "Request no longer pending"),
                    message: String(localized: "This request was already resolved on the other side, so nothing was changed.")
                )
                return
            }
            serverRequest.familyID = request.familyID
            let memberID = serverRequest.memberID

            // A request for a member that no longer exists must not be
            // applied — it would recreate orphaned day records.
            guard member(memberID) != nil else {
                alert = AppAlert(
                    title: String(localized: "Member removed"),
                    message: String(localized: "This request concerns a child or pet that was removed, so it can't be applied.")
                )
                return
            }

            // Skip days that changed since the request was proposed, so an
            // approval can never silently overwrite newer agreements.
            var validChanges: [DayChange] = []
            var staleCount = 0
            for change in serverRequest.changes {
                let current = owner(of: memberID, on: change.dateKey)
                if current == change.newOwner { continue }
                if current == change.oldOwner {
                    validChanges.append(change)
                } else {
                    staleCount += 1
                }
            }

            var dayRecords: [CKRecord] = []
            for change in validChanges {
                let recordName = DayAssignment.recordName(member: memberID, dateKey: change.dateKey)
                let record = service.newRecord(type: RecordType.dayAssignment, name: recordName, in: handle)
                DayAssignment(memberID: memberID, dateKey: change.dateKey, owner: change.newOwner, assignedBy: nil).apply(to: record)
                dayRecords.append(record)
            }
            var resolved = serverRequest
            resolved.status = .approved
            resolved.resolvedAt = Date()
            let requestRecord = service.newRecord(type: RecordType.changeRequest, name: request.id, in: handle)
            resolved.apply(to: requestRecord)

            // Save day changes and the approval together (atomically) when
            // they fit CloudKit's per-operation limit; chunk only huge ones.
            if dayRecords.count <= 350 {
                try await service.save(records: dayRecords + [requestRecord], in: handle)
            } else {
                for chunk in dayRecords.chunked(into: 200) {
                    try await service.save(records: chunk, in: handle)
                }
                try await service.save(records: [requestRecord], in: handle)
            }

            for change in validChanges {
                assignments[memberID, default: [:]][change.dateKey] = change.newOwner
                directAssigner[memberID]?.removeValue(forKey: change.dateKey)
            }
            upsert(resolved)
            rebuildDerived()
            rememberRequestStatus(resolved)
            saveCache()

            if staleCount > 0 {
                alert = AppAlert(
                    title: String(localized: "Some days were skipped"),
                    message: String(localized: "\(staleCount) days had already changed since this was proposed, so they were left as they are now.")
                )
            }
        } catch {
            presentError(error)
        }
    }

    func decline(_ request: ChangeRequest) async {
        guard request.isPending, request.requester != myRole(in: request.familyID) else { return }
        await resolve(request, as: .declined)
    }

    func cancel(_ request: ChangeRequest) async {
        guard request.isPending, request.requester == myRole(in: request.familyID) else { return }
        await resolve(request, as: .cancelled)
    }

    private func resolve(_ request: ChangeRequest, as status: ChangeRequest.Status) async {
        guard let familyRef = ref(request.familyID) else { return }
        let handle = service.handle(for: familyRef)
        do {
            var resolved = request
            resolved.status = status
            resolved.resolvedAt = Date()
            let record = service.newRecord(type: RecordType.changeRequest, name: request.id, in: handle)
            resolved.apply(to: record)
            try await service.save(records: [record], in: handle)
            upsert(resolved)
            rebuildDerived()
            rememberRequestStatus(resolved)
            saveCache()
        } catch {
            presentError(error)
        }
    }

    // MARK: - Patterns

    struct PatternOutcome {
        var appliedDirectly: Int
        var sentForApproval: Int
        var skippedPending: Int
    }

    /// Applies a generated schedule to ONE member. While that family is
    /// still solo it applies immediately; once its co-parent is connected,
    /// a bulk schedule always becomes ONE approval request (all-or-nothing).
    /// Days inside pending requests are always skipped.
    func applyPattern(member memberID: String, proposal: [String: ParentRole]) async -> PatternOutcome? {
        guard let ctx = context(memberID), let familyRef = ref(ctx.familyID) else { return nil }
        let handle = service.handle(for: familyRef)
        var differing: [(String, ParentRole)] = []
        var skippedPending = 0

        for (dateKey, newOwner) in proposal.sorted(by: { $0.key < $1.key }) {
            if owner(of: memberID, on: dateKey) == newOwner { continue }
            if isPending(memberID, dateKey) {
                skippedPending += 1
                continue
            }
            differing.append((dateKey, newOwner))
        }

        guard !differing.isEmpty else {
            return PatternOutcome(appliedDirectly: 0, sentForApproval: 0, skippedPending: skippedPending)
        }

        do {
            if ctx.partnerJoined {
                let changes = differing.map { key, newOwner in
                    DayChange(dateKey: key, newOwner: newOwner, oldOwner: owner(of: memberID, on: key))
                }
                let sent = await submitRequest(member: memberID, changes: changes, message: "", kind: .pattern)
                if !sent { return nil }
                return PatternOutcome(appliedDirectly: 0, sentForApproval: changes.count, skippedPending: skippedPending)
            } else {
                var records: [CKRecord] = []
                for (key, newOwner) in differing {
                    let recordName = DayAssignment.recordName(member: memberID, dateKey: key)
                    let record = service.newRecord(type: RecordType.dayAssignment, name: recordName, in: handle)
                    DayAssignment(memberID: memberID, dateKey: key, owner: newOwner, assignedBy: newOwner).apply(to: record)
                    records.append(record)
                }
                for chunk in records.chunked(into: 200) {
                    try await service.save(records: chunk, in: handle)
                }
                for (key, newOwner) in differing {
                    assignments[memberID, default: [:]][key] = newOwner
                    directAssigner[memberID, default: [:]][key] = newOwner
                }
                saveCache()
                return PatternOutcome(appliedDirectly: differing.count, sentForApproval: 0, skippedPending: skippedPending)
            }
        } catch {
            presentError(error)
            return nil
        }
    }

    // MARK: - Per-family settings actions

    func updateProfile(familyID: String, myName: String, myColorHex: String) async {
        guard var updated = families[familyID], let familyRef = ref(familyID) else { return }
        let handle = service.handle(for: familyRef)
        do {
            let record = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName, in: handle)
            if familyRef.role == .parentA {
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
            try await service.save(records: [record], in: handle)
            families[familyID] = updated
            saveCache()
        } catch {
            presentError(error)
        }
    }

    /// Owner deletes the calendar for everyone; participant just leaves it.
    /// Only affects ONE family — others keep working.
    func leaveFamily(_ familyID: String) async {
        guard let familyRef = ref(familyID) else { return }
        do {
            try await service.deleteZone(in: service.handle(for: familyRef))
            removeFamilyLocally(familyID)
        } catch {
            presentError(error)
        }
    }

    /// Owner-only: disconnects one family's co-parent. The share is deleted
    /// outright, so their access AND the old invitation link die permanently;
    /// a fresh link is minted the next time the invitation is shown. That
    /// family's pending requests are cancelled. Nothing local is touched
    /// until the server-side revocation succeeds.
    func removeCoParent(familyID: String) async {
        guard let familyRef = ref(familyID), familyRef.role == .parentA else { return }
        let handle = service.handle(for: familyRef)
        do {
            let shareID = service.recordID(forName: CKRecordNameZoneWideShare, in: handle)
            do {
                try await service.save(records: [], deleting: [shareID], in: handle)
            } catch let error where Self.normalizedCKErrorCode(error) == .unknownItem {
                // Share already gone — revocation is already effective.
            }

            var records: [CKRecord] = []
            let familyRecord = try await service.fetchOrCreateRecord(type: RecordType.family, name: Family.recordName, in: handle)
            familyRecord["nameB"] = ""
            records.append(familyRecord)

            var cancelled: [ChangeRequest] = []
            for request in requests where request.isPending && request.familyID == familyID {
                var resolved = request
                resolved.status = .cancelled
                resolved.resolvedAt = Date()
                let record = service.newRecord(type: RecordType.changeRequest, name: request.id, in: handle)
                resolved.apply(to: record)
                records.append(record)
                cancelled.append(resolved)
            }
            try await service.save(records: records, in: handle)

            if var updated = families[familyID] {
                updated.nameB = ""
                families[familyID] = updated
            }
            for request in cancelled {
                upsert(request)
                rememberRequestStatus(request)
            }
            rebuildDerived()
            shareURLs.removeValue(forKey: familyID)
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: Keys.shareURL(familyID))
            defaults.set(false, forKey: Keys.shareLocked(familyID))
            saveCache()
        } catch {
            presentError(error)
        }
    }

    /// Owner-only: makes sure a live invitation exists for one family
    /// (e.g. after removing its co-parent). Called by InviteView.
    func ensureInvitationReady(familyID: String) async {
        guard let familyRef = ref(familyID), familyRef.role == .parentA,
              shareURLs[familyID] == nil, families[familyID] != nil
        else { return }
        do {
            let title: String
            if let firstName = membersOf(familyID).first?.name, !firstName.isEmpty {
                title = String(localized: "Custody calendar for \(firstName)")
            } else {
                title = "Nido"
            }
            let url = try await service.createZoneAndShare(zoneName: familyRef.zoneName, title: title)
            shareURLs[familyID] = url
            UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL(familyID))
        } catch {
            presentError(error)
        }
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

    private func recordAllRequestStatuses() {
        var statuses: [String: String] = [:]
        for request in requests {
            statuses[request.id] = request.status.rawValue
        }
        UserDefaults.standard.set(statuses, forKey: Keys.requestStatuses)
    }

    private func notifyAboutChanges(
        previousStatuses: [String: String],
        outcomes: [(familyID: String, outcome: ApplyOutcome)],
        partnerWasJoined: [String: Bool]
    ) {
        for (familyID, outcome) in outcomes {
            let coParent = families[familyID]?.name(of: myRole(in: familyID).other) ?? String(localized: "Co-parent")

            if myRole(in: familyID) == .parentA,
               partnerWasJoined[familyID] == false,
               families[familyID]?.partnerHasJoined == true {
                postLocalNotification(
                    id: "joined-\(familyID)-\(Int(Date().timeIntervalSince1970))",
                    title: String(localized: "Co-parent joined 🎉"),
                    body: String(localized: "\(coParent) joined the calendar. You can now plan together.")
                )
            }

            // Member additions and removals by a co-parent are never silent.
            for name in outcome.addedMemberNames {
                postLocalNotification(
                    id: "member-added-\(name)-\(Int(Date().timeIntervalSince1970))",
                    title: String(localized: "Family updated"),
                    body: String(localized: "\(coParent) added \(name) to Nido.")
                )
            }
            for deleted in outcome.deletedMembers {
                let body = deleted.dayCount > 0
                    ? String(localized: "\(coParent) removed \(deleted.name)'s calendar, including \(deleted.dayCount) assigned days.")
                    : String(localized: "\(coParent) removed \(deleted.name) from Nido.")
                postLocalNotification(
                    id: "member-removed-\(deleted.name)-\(Int(Date().timeIntervalSince1970))",
                    title: String(localized: "Calendar removed"),
                    body: body
                )
            }
        }

        var statuses: [String: String] = [:]
        var daysExplainedByRequests: Set<String> = []

        for request in requests {
            let previous = previousStatuses[request.id]
            statuses[request.id] = request.status.rawValue
            let mine = request.requester == myRole(in: request.familyID)
            let coParent = otherPartyName(of: request)

            if previous != request.status.rawValue {
                daysExplainedByRequests.formUnion(request.changes.map { request.memberID + "|" + $0.dateKey })
            }

            if !mine, request.isPending, previous == nil {
                let count = request.changes.count
                let memberName = member(request.memberID)?.name ?? ""
                let body = count == 1
                    ? String(localized: "\(coParent) proposes a change for \(memberName): \(Day.shortLabel(for: request.changes[0].dateKey)).")
                    : String(localized: "\(coParent) proposes changes to \(count) of \(memberName)'s days.")
                postLocalNotification(
                    id: "request-\(request.id)",
                    title: String(localized: "New change request"),
                    body: body
                )
            }

            // Transitions out of pending are only ever remote here: my own
            // approve/decline/cancel actions pre-record their status, so
            // they never appear as a transition.
            if mine, previous == ChangeRequest.Status.pending.rawValue, !request.isPending {
                switch request.status {
                case .approved:
                    postLocalNotification(
                        id: "resolved-\(request.id)",
                        title: String(localized: "Request approved 🎉"),
                        body: String(localized: "\(coParent) approved your schedule change.")
                    )
                case .declined:
                    postLocalNotification(
                        id: "resolved-\(request.id)",
                        title: String(localized: "Request declined"),
                        body: String(localized: "\(coParent) declined your schedule change.")
                    )
                case .cancelled:
                    let body: String
                    if let memberName = member(request.memberID)?.name {
                        body = String(localized: "Your pending request for \(memberName) was cancelled.")
                    } else {
                        body = String(localized: "Your pending request was cancelled.")
                    }
                    postLocalNotification(
                        id: "resolved-\(request.id)",
                        title: String(localized: "Request cancelled"),
                        body: body
                    )
                case .pending:
                    break
                }
            }
        }
        UserDefaults.standard.set(statuses, forKey: Keys.requestStatuses)

        // Direct assignments made by a co-parent (not explained by any
        // request activity) also deserve a heads-up — no silent rescheduling.
        for (familyID, outcome) in outcomes {
            guard families[familyID]?.partnerHasJoined == true else { continue }
            let coParent = families[familyID]?.name(of: myRole(in: familyID).other) ?? ""
            let unexplained = outcome.changedDays.subtracting(daysExplainedByRequests)
            guard !unexplained.isEmpty else { continue }
            var byMember: [String: [String]] = [:]
            for composite in unexplained {
                let parts = composite.split(separator: "|", maxSplits: 1)
                guard parts.count == 2 else { continue }
                byMember[String(parts[0]), default: []].append(String(parts[1]))
            }
            let body: String
            if byMember.count == 1, let (memberID, dates) = byMember.first {
                let memberName = member(memberID)?.name ?? ""
                body = dates.count == 1
                    ? String(localized: "\(coParent) updated \(memberName)'s day \(Day.shortLabel(for: dates[0])).")
                    : String(localized: "\(coParent) updated \(dates.count) of \(memberName)'s days.")
            } else {
                body = String(localized: "\(coParent) updated \(unexplained.count) days on the calendar.")
            }
            postLocalNotification(
                id: "days-\(familyID)-\(Int(Date().timeIntervalSince1970))",
                title: String(localized: "Calendar updated"),
                body: body
            )
        }
    }

    private func postLocalNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Change token persistence (per family)

    private func changeToken(for familyID: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: Keys.changeToken(familyID)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func setChangeToken(_ token: CKServerChangeToken?, for familyID: String) {
        let defaults = UserDefaults.standard
        if let token,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            defaults.set(data, forKey: Keys.changeToken(familyID))
        } else {
            defaults.removeObject(forKey: Keys.changeToken(familyID))
        }
    }

    // MARK: - Offline cache

    private struct CachePayload: Codable {
        var families: [String: Family]
        var membersByID: [String: Member]
        var memberFamily: [String: String]
        var assignments: [String: [String: ParentRole]]
        var directAssigner: [String: [String: ParentRole]]
        var notes: [String: [String: String]]
        var requests: [ChangeRequest]
        var shareURLs: [String: URL]
    }

    private static var cacheURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("nido-cache.json")
    }

    private func saveCache() {
        let payload = CachePayload(
            families: families,
            membersByID: membersByID,
            memberFamily: memberFamily,
            assignments: assignments,
            directAssigner: directAssigner,
            notes: notes,
            requests: requests,
            shareURLs: shareURLs
        )
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data)
        else { return }
        families = payload.families
        membersByID = payload.membersByID
        memberFamily = payload.memberFamily
        assignments = payload.assignments
        directAssigner = payload.directAssigner
        notes = payload.notes
        requests = payload.requests
        shareURLs = payload.shareURLs
        rebuildDerived()
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
