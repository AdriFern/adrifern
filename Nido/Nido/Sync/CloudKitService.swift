import CloudKit
import Foundation

/// Thin wrapper around CloudKit. The family lives in one custom record zone:
/// in the owner's (parent A) private database, shared with parent B through a
/// zone-wide CKShare. Parent B reaches the same zone via the shared database.
@MainActor
final class CloudKitService {
    static let zoneName = "FamilyZone"

    let container: CKContainer

    /// True for the parent who created the family (records live in the private DB).
    private(set) var isOwner: Bool
    private(set) var zoneID: CKRecordZone.ID

    init(isOwner: Bool, zoneOwnerName: String?) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.adrifern.nido"
        self.container = CKContainer(identifier: "iCloud.\(bundleID)")
        self.isOwner = isOwner
        self.zoneID = CKRecordZone.ID(
            zoneName: Self.zoneName,
            ownerName: zoneOwnerName ?? CKCurrentUserDefaultName
        )
    }

    var database: CKDatabase {
        isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    func configure(isOwner: Bool, zoneOwnerName: String?) {
        self.isOwner = isOwner
        self.zoneID = CKRecordZone.ID(
            zoneName: Self.zoneName,
            ownerName: zoneOwnerName ?? CKCurrentUserDefaultName
        )
    }

    // MARK: - Account

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    // MARK: - Zone + share (owner side)

    /// Creates the custom zone and a zone-wide share, returning the invitation URL.
    /// Safe to call again after a reinstall: an existing share is reused.
    func createZoneAndShare(title: String) async throws -> URL {
        let zone = CKRecordZone(zoneName: Self.zoneName)
        _ = try await container.privateCloudDatabase.save(zone)

        // A zone can only carry one zone-wide share; reuse it if it exists
        // (e.g. the app was deleted and reinstalled).
        if let existing = try? await fetchShare(), let url = existing.url {
            return url
        }

        let share = CKShare(recordZoneID: zone.zoneID)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = title
        do {
            let saved = try await save(records: [share], in: container.privateCloudDatabase)
            guard let savedShare = saved.compactMap({ $0 as? CKShare }).first,
                  let url = savedShare.url
            else { throw NidoError.shareURLMissing }
            return url
        } catch {
            // The save can fail because a share already exists but the
            // earlier lookup hit a transient error — try the lookup again
            // before surfacing a cryptic CloudKit message.
            if let existing = try? await fetchShare(), let url = existing.url {
                return url
            }
            throw error
        }
    }

    /// Re-fetches the zone share to recover the invitation URL and participant list.
    func fetchShare() async throws -> CKShare? {
        let shareRecordID = CKRecord.ID(
            recordName: CKRecordNameZoneWideShare,
            zoneID: zoneID
        )
        do {
            let record = try await database.record(for: shareRecordID)
            return record as? CKShare
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
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

    /// Incremental fetch of everything that changed in the family zone.
    func fetchZoneChanges(since token: CKServerChangeToken?) async throws -> ZoneChanges {
        var changes = ZoneChanges()
        var currentToken = token
        var moreComing = true

        while moreComing {
            moreComing = false
            let batch: ZoneChanges = try await withCheckedThrowingContinuation { continuation in
                let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                configuration.previousServerChangeToken = currentToken

                let operation = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [zoneID],
                    configurationsByRecordZoneID: [zoneID: configuration]
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
                self.database.add(operation)
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

    func recordID(forName name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    func newRecord(type: String, name: String) -> CKRecord {
        CKRecord(recordType: type, recordID: recordID(forName: name))
    }

    /// Saves with last-writer-wins semantics; fine for a two-person calendar.
    @discardableResult
    func save(records: [CKRecord], deleting recordIDs: [CKRecord.ID] = [], in databaseOverride: CKDatabase? = nil) async throws -> [CKRecord] {
        let db = databaseOverride ?? database
        let (saveResults, deleteResults) = try await db.modifyRecords(
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
    func fetchOrCreateRecord(type: String, name: String) async throws -> CKRecord {
        do {
            return try await database.record(for: recordID(forName: name))
        } catch let error as CKError where error.code == .unknownItem {
            return newRecord(type: type, name: name)
        }
    }

    // MARK: - Subscriptions (push)

    func saveSubscriptions() async throws {
        // A visible (localized, generic) alert makes delivery reliable even
        // when the app is force-quit; content-available additionally wakes
        // the app to refresh and post specific local notifications.
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertLocalizationKey = "PUSH_CALENDAR_UPDATED"
        notificationInfo.soundName = "default"

        if isOwner {
            let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "nido-zone-changes")
            subscription.notificationInfo = notificationInfo
            _ = try await container.privateCloudDatabase.save(subscription)
        } else {
            let subscription = CKDatabaseSubscription(subscriptionID: "nido-shared-changes")
            subscription.notificationInfo = notificationInfo
            _ = try await container.sharedCloudDatabase.save(subscription)
        }
    }

    // MARK: - Leaving / deleting

    /// Owner: deletes the whole zone. Participant: removes themself from the share.
    func deleteZone() async throws {
        _ = try await database.deleteRecordZone(withID: zoneID)
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
