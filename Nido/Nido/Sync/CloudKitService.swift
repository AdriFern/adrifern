import CloudKit
import Foundation

/// Thin wrapper around CloudKit. Every family lives in its own record zone:
/// zones the user created sit in their private database (shared out through
/// a zone-wide CKShare); zones they were invited to are reached through the
/// shared database. One person can hold several such zones at once — one
/// per co-parenting relationship.
@MainActor
final class CloudKitService {
    static let zonePrefix = "FamilyZone"

    let container: CKContainer

    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.adrifern.nido"
        self.container = CKContainer(identifier: "iCloud.\(bundleID)")
    }

    /// Everything needed to address one family's zone.
    struct ZoneHandle {
        let database: CKDatabase
        let zoneID: CKRecordZone.ID
    }

    func handle(for ref: FamilyRef) -> ZoneHandle {
        if ref.role == .parentA {
            return ZoneHandle(
                database: container.privateCloudDatabase,
                zoneID: CKRecordZone.ID(zoneName: ref.zoneName, ownerName: CKCurrentUserDefaultName)
            )
        }
        return ZoneHandle(
            database: container.sharedCloudDatabase,
            zoneID: CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.zoneOwnerName ?? CKCurrentUserDefaultName)
        )
    }

    // MARK: - Account

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    // MARK: - Zone + share (owner side)

    /// Creates a custom zone and a zone-wide share, returning the invitation
    /// URL. Safe to call again for the same zone: an existing share is reused.
    func createZoneAndShare(zoneName: String, title: String) async throws -> URL {
        let zone = CKRecordZone(zoneName: zoneName)
        _ = try await container.privateCloudDatabase.save(zone)

        let handle = ZoneHandle(database: container.privateCloudDatabase, zoneID: zone.zoneID)
        if let existing = try? await fetchShare(in: handle), let url = existing.url {
            return url
        }

        let share = CKShare(recordZoneID: zone.zoneID)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = title
        do {
            let saved = try await save(records: [share], in: handle)
            guard let savedShare = saved.compactMap({ $0 as? CKShare }).first,
                  let url = savedShare.url
            else { throw NidoError.shareURLMissing }
            return url
        } catch {
            // The save can fail because a share already exists but the
            // earlier lookup hit a transient error — try the lookup again
            // before surfacing a cryptic CloudKit message.
            if let existing = try? await fetchShare(in: handle), let url = existing.url {
                return url
            }
            throw error
        }
    }

    /// Re-fetches a zone's share to recover the invitation URL.
    func fetchShare(in handle: ZoneHandle) async throws -> CKShare? {
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: handle.zoneID)
        do {
            let record = try await handle.database.record(for: shareRecordID)
            return record as? CKShare
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// All family zones this account can reach, owned and shared.
    func listFamilyZones() async throws -> (owned: [CKRecordZone], shared: [CKRecordZone]) {
        let owned = try await container.privateCloudDatabase.allRecordZones()
            .filter { $0.zoneID.zoneName.hasPrefix(Self.zonePrefix) }
        let shared = try await container.sharedCloudDatabase.allRecordZones()
            .filter { $0.zoneID.zoneName.hasPrefix(Self.zonePrefix) }
        return (owned, shared)
    }

    // MARK: - Share acceptance (joiner side)

    func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            var metadata: CKShare.Metadata?
            operation.perShareMetadataResultBlock = { _, result in
                if case .success(let value) = result { metadata = value }
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NidoError.invalidInvitation)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            operation.qualityOfService = .userInitiated
            container.add(operation)
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }

    // MARK: - Fetching changes

    struct ZoneChanges {
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)] = []
        var changeToken: CKServerChangeToken?
        var moreComing = false
    }

    /// Incremental fetch of everything that changed in one family's zone.
    func fetchZoneChanges(in handle: ZoneHandle, since token: CKServerChangeToken?) async throws -> ZoneChanges {
        var changes = ZoneChanges()
        var currentToken = token
        var moreComing = true

        while moreComing {
            moreComing = false
            let batch: ZoneChanges = try await withCheckedThrowingContinuation { continuation in
                let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                configuration.previousServerChangeToken = currentToken

                let operation = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [handle.zoneID],
                    configurationsByRecordZoneID: [handle.zoneID: configuration]
                )
                var partial = ZoneChanges()

                operation.recordWasChangedBlock = { _, result in
                    if case .success(let record) = result {
                        partial.changedRecords.append(record)
                    }
                }
                operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                    partial.deletedRecordIDs.append((recordID, recordType))
                }
                var zoneError: Error?
                operation.recordZoneFetchResultBlock = { _, result in
                    switch result {
                    case .success(let (serverToken, _, more)):
                        partial.changeToken = serverToken
                        partial.moreComing = more
                    case .failure(let error):
                        // Zone-level errors (expired token, deleted zone,
                        // revoked access) arrive here, not at operation level.
                        zoneError = error
                    }
                }
                operation.fetchRecordZoneChangesResultBlock = { result in
                    if let zoneError {
                        continuation.resume(throwing: zoneError)
                        return
                    }
                    switch result {
                    case .success:
                        continuation.resume(returning: partial)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                operation.qualityOfService = .userInitiated
                handle.database.add(operation)
            }

            changes.changedRecords.append(contentsOf: batch.changedRecords)
            changes.deletedRecordIDs.append(contentsOf: batch.deletedRecordIDs)
            if let newToken = batch.changeToken {
                changes.changeToken = newToken
                currentToken = newToken
            }
            moreComing = batch.moreComing
        }
        return changes
    }

    // MARK: - Saving

    func recordID(forName name: String, in handle: ZoneHandle) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: handle.zoneID)
    }

    func newRecord(type: String, name: String, in handle: ZoneHandle) -> CKRecord {
        CKRecord(recordType: type, recordID: recordID(forName: name, in: handle))
    }

    /// Saves with last-writer-wins semantics; fine for a two-person calendar.
    @discardableResult
    func save(records: [CKRecord], deleting recordIDs: [CKRecord.ID] = [], in handle: ZoneHandle) async throws -> [CKRecord] {
        let (saveResults, deleteResults) = try await handle.database.modifyRecords(
            saving: records,
            deleting: recordIDs,
            savePolicy: .changedKeys,
            atomically: true
        )
        var saved: [CKRecord] = []
        for (_, result) in saveResults {
            saved.append(try result.get())
        }
        for (_, result) in deleteResults {
            _ = try result.get()
        }
        return saved
    }

    /// Fetches an existing record by name, or creates a new one if it doesn't exist yet.
    func fetchOrCreateRecord(type: String, name: String, in handle: ZoneHandle) async throws -> CKRecord {
        do {
            return try await handle.database.record(for: recordID(forName: name, in: handle))
        } catch let error as CKError where error.code == .unknownItem {
            return newRecord(type: type, name: name, in: handle)
        }
    }

    // MARK: - Subscriptions (push)

    private static var notificationInfo: CKSubscription.NotificationInfo {
        // A visible (localized, generic) alert makes delivery reliable even
        // when the app is force-quit; content-available additionally wakes
        // the app to refresh and post specific local notifications.
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.alertLocalizationKey = "PUSH_CALENDAR_UPDATED"
        info.soundName = "default"
        return info
    }

    /// Owner side: one subscription per owned family zone.
    func saveZoneSubscription(zoneName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "nido-zone-\(zoneName)")
        subscription.notificationInfo = Self.notificationInfo
        _ = try await container.privateCloudDatabase.save(subscription)
    }

    /// Removes the subscription id used before multi-family support so the
    /// legacy zone doesn't push twice after an upgrade.
    func deleteLegacyZoneSubscription() async {
        _ = try? await container.privateCloudDatabase.deleteSubscription(withID: "nido-zone-changes")
    }

    /// Participant side: one database subscription covers every shared zone.
    func saveSharedDatabaseSubscription() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "nido-shared-changes")
        subscription.notificationInfo = Self.notificationInfo
        _ = try await container.sharedCloudDatabase.save(subscription)
    }

    // MARK: - Leaving / deleting

    /// Owner: deletes the whole zone. Participant: removes themself from the share.
    func deleteZone(in handle: ZoneHandle) async throws {
        _ = try await handle.database.deleteRecordZone(withID: handle.zoneID)
    }
}

// MARK: - Errors

enum NidoError: LocalizedError {
    case shareURLMissing
    case invalidInvitation

    var errorDescription: String? {
        switch self {
        case .shareURLMissing:
            String(localized: "The invitation link could not be created. Please try again.")
        case .invalidInvitation:
            String(localized: "That doesn't look like a valid Nido invitation.")
        }
    }
}
