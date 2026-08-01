import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for upcoming occurrences and handles
/// notification actions (Done / Snooze). Everything is on-device.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    static let categoryID = "ROUTINE_REMINDER"
    static let actionDone = "MARK_DONE"
    static let actionSnooze = "SNOOZE_10"

    /// How many alarm-mode follow-up nags to schedule after the initial alert.
    static let nagCount = 3
    /// Minutes between alarm-mode nags.
    static let nagInterval = 5

    var container: ModelContainer?

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
    }

    func configure(container: ModelContainer) {
        self.container = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let done = UNNotificationAction(identifier: Self.actionDone, title: "Mark done", options: [])
        let snooze = UNNotificationAction(identifier: Self.actionSnooze, title: "Snooze 10 min", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: [done, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.authorizationStatus = settings.authorizationStatus
        }
    }

    func requestAuthorization() {
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            self.refreshAuthorizationStatus()
            self.syncAll()
        }
    }

    // MARK: - Scheduling

    /// Rebuilds all pending notifications from the current data. Called after any
    /// edit, completion, or when the app becomes active. iOS caps pending local
    /// notifications at 64, so we schedule the nearest ones over the next 14 days.
    func syncAll() {
        guard let container else { return }
        let context = container.mainContext
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let contexts = (try? context.fetch(FetchDescriptor<ContextTag>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        let doneKeys = Set(completions.filter { $0.isDone }.map { "\($0.routineID.uuidString)-\($0.dayKey)-\($0.slotMinutes)" })

        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let occurrences = Scheduler.upcomingOccurrences(for: routines, contexts: contexts, days: 14)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var budget = 60
        for occurrence in occurrences {
            guard budget > 0 else { break }
            guard let routine = routineMap[occurrence.routineID], routine.alertMode != .none else { continue }
            guard !doneKeys.contains(occurrence.id) else { continue }

            add(occurrence: occurrence, routine: routine, to: center)
            budget -= 1

            if routine.alertMode == .alarm {
                for nag in 1...Self.nagCount {
                    guard budget > 0 else { break }
                    let fireDate = occurrence.fireDate.addingTimeInterval(TimeInterval(nag * Self.nagInterval * 60))
                    add(occurrence: occurrence, routine: routine, to: center, fireDate: fireDate, nagIndex: nag)
                    budget -= 1
                }
            }
        }
    }

    private func add(occurrence: Occurrence, routine: Routine, to center: UNUserNotificationCenter, fireDate: Date? = nil, nagIndex: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = nagIndex == 0 ? routine.title : "Still to do: \(routine.title)"
        var body = routine.notes
        if !routine.items.isEmpty {
            let itemList = routine.sortedItems.map { $0.title }.joined(separator: ", ")
            body = body.isEmpty ? itemList : body + "\n" + itemList
        }
        if nagIndex > 0 {
            body = body.isEmpty ? "Tap Mark done when finished." : body
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        if routine.alertMode == .alarm {
            content.interruptionLevel = .timeSensitive
        }
        content.userInfo = [
            "routineID": occurrence.routineID.uuidString,
            "dayKey": Scheduler.dayKey(for: occurrence.day),
            "slotMinutes": occurrence.slotMinutes,
        ]

        let date = fireDate ?? occurrence.fireDate
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let identifier = nagIndex == 0 ? occurrence.id : "\(occurrence.id)-nag\(nagIndex)"
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Cancels the pending notifications (including nags) for one occurrence,
    /// e.g. after it is marked done.
    func cancel(occurrenceID: String) {
        var ids = [occurrenceID]
        for nag in 1...Self.nagCount {
            ids.append("\(occurrenceID)-nag\(nag)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Completion from notification actions

    private func markDone(routineID: UUID, dayKey: String, slotMinutes: Int) {
        guard let container else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.routineID == routineID && $0.dayKey == dayKey && $0.slotMinutes == slotMinutes }
        )
        let record: CompletionRecord
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = CompletionRecord(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes)
            context.insert(record)
        }
        record.isDone = true
        record.completedAt = .now
        try? context.save()
        cancel(occurrenceID: "\(routineID.uuidString)-\(dayKey)-\(slotMinutes)")
    }

    private func snooze(routineID: UUID, dayKey: String, slotMinutes: Int, title: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Snoozed reminder"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["routineID": routineID.uuidString, "dayKey": dayKey, "slotMinutes": slotMinutes]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let id = "\(routineID.uuidString)-\(dayKey)-\(slotMinutes)-snooze-\(UUID().uuidString.prefix(8))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["routineID"] as? String,
              let routineID = UUID(uuidString: idString),
              let dayKey = userInfo["dayKey"] as? String,
              let slotMinutes = userInfo["slotMinutes"] as? Int else { return }
        let title = response.notification.request.content.title
        let actionID = response.actionIdentifier

        await MainActor.run {
            switch actionID {
            case Self.actionDone:
                self.markDone(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes)
            case Self.actionSnooze:
                self.snooze(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes, title: title)
            default:
                break
            }
        }
    }
}
