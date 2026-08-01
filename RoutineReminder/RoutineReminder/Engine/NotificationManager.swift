import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for upcoming occurrences and handles
/// notification actions (Done / Snooze). Everything is on-device.
///
/// Scheduling strategy (iOS caps pending local notifications at 64):
/// - All *base* alerts over the next 14 days are scheduled first, then alarm-mode
///   nags fill the remaining budget — a few alarm routines can't starve day-10
///   base reminders.
/// - Re-syncs are DIFF-based: we never call removeAllPendingNotificationRequests,
///   so live snoozes and in-flight nag chains survive the user opening the app.
/// - A "re-arm" sentinel fires near the end of the horizon if the user hasn't
///   opened the app, so reminders can never just silently stop.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    static let categoryID = "ROUTINE_REMINDER"
    static let actionDone = "MARK_DONE"
    static let actionSnooze = "SNOOZE"
    static let sentinelID = "rearm-sentinel"
    static let horizonDays = 14
    static let requestBudget = 60

    var container: ModelContainer?

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Set when the user taps a notification body; the UI navigates to it.
    @Published var openRequest: OpenTarget?

    struct OpenTarget: Equatable {
        let routineID: UUID
        let day: Date
    }

    private override init() {
        super.init()
    }

    func configure(container: ModelContainer) {
        self.container = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Done is state-changing (it cancels safety nags and writes history),
        // so it requires the device to be unlocked. Snooze stays frictionless.
        let done = UNNotificationAction(identifier: Self.actionDone,
                                        title: String(localized: "Mark done"),
                                        options: [.authenticationRequired])
        let snooze = UNNotificationAction(identifier: Self.actionSnooze,
                                          title: String(localized: "Snooze"),
                                          options: [])
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
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            self.refreshAuthorizationStatus()
            self.syncAll()
        }
    }

    // MARK: - Scheduling

    func syncAll() {
        Task { @MainActor in
            await self.performSync()
        }
    }

    private func performSync() async {
        guard let container else { return }
        let context = container.mainContext
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let contexts = (try? context.fetch(FetchDescriptor<ContextTag>())) ?? []
        let todayKey = Scheduler.dayKey(for: .now)
        let doneDescriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate<CompletionRecord> { $0.isDone && $0.dayKey >= todayKey }
        )
        let doneRecords = (try? context.fetch(doneDescriptor)) ?? []
        let doneKeys = Set(doneRecords.map { "\($0.routineID.uuidString)-\($0.dayKey)-\($0.slotMinutes)" })

        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let occurrences = Scheduler.upcomingOccurrences(for: routines, contexts: contexts, days: Self.horizonDays)
        let settings = AppSettings.shared
        let now = Date.now

        // Build the desired request set: all future bases first, then nags.
        var desired: [(id: String, request: UNNotificationRequest)] = []
        var baseRequests: [(Occurrence, Routine)] = []
        var nagRequests: [(Occurrence, Routine, Int, Date)] = []

        for occurrence in occurrences {
            guard let routine = routineMap[occurrence.routineID],
                  routine.alertMode != .none,
                  !doneKeys.contains(occurrence.id) else { continue }
            if occurrence.fireDate > now {
                baseRequests.append((occurrence, routine))
            }
            if routine.alertMode == .alarm {
                for nag in 1...max(1, settings.nagCount) {
                    let nagDate = occurrence.fireDate.addingTimeInterval(TimeInterval(nag * settings.nagIntervalMinutes * 60))
                    if nagDate > now {
                        nagRequests.append((occurrence, routine, nag, nagDate))
                    }
                }
            }
        }

        var budget = Self.requestBudget
        for (occurrence, routine) in baseRequests where budget > 0 {
            desired.append((occurrence.id, makeRequest(occurrence: occurrence, routine: routine,
                                                       fireDate: occurrence.fireDate, nagIndex: 0)))
            budget -= 1
        }
        for (occurrence, routine, nag, nagDate) in nagRequests.sorted(by: { $0.3 < $1.3 }) where budget > 0 {
            let id = "\(occurrence.id)-nag\(nag)"
            desired.append((id, makeRequest(occurrence: occurrence, routine: routine,
                                            fireDate: nagDate, nagIndex: nag, identifier: id)))
            budget -= 1
        }

        // Re-arm sentinel: quiet nudge near the end of the horizon.
        if !baseRequests.isEmpty {
            desired.append((Self.sentinelID, makeSentinel()))
        }

        // Diff against what's pending: keep live snoozes (they're relative
        // triggers we can't rebuild), drop everything stale, add the rest.
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let desiredIDs = Set(desired.map { $0.id })

        var staleIDs: [String] = []
        for request in pending {
            let id = request.identifier
            if id.contains("-snooze") {
                // Preserve unless its occurrence is already done.
                let baseID = String(id.prefix(upTo: id.range(of: "-snooze")!.lowerBound))
                if doneKeys.contains(baseID) { staleIDs.append(id) }
            } else if !desiredIDs.contains(id) {
                staleIDs.append(id)
            }
        }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }
        for (_, request) in desired {
            try? await center.add(request)
        }
    }

    private func makeRequest(occurrence: Occurrence, routine: Routine,
                             fireDate: Date, nagIndex: Int, identifier: String? = nil) -> UNNotificationRequest {
        let content = baseContent(routine: routine, occurrence: occurrence, nagIndex: nagIndex)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: identifier ?? occurrence.id, content: content, trigger: trigger)
    }

    private func baseContent(routine: Routine, occurrence: Occurrence, nagIndex: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let settings = AppSettings.shared
        if settings.privateNotifications {
            content.title = nagIndex == 0
                ? String(localized: "Routine reminder")
                : String(localized: "Still waiting on a routine")
            content.body = String(localized: "Open the app to see the details.")
        } else {
            content.title = nagIndex == 0 ? routine.title : String(localized: "Still to do: \(routine.title)")
            var body = routine.notes
            if !routine.items.isEmpty {
                let itemList = routine.sortedItems.map { $0.title }.joined(separator: ", ")
                body = body.isEmpty ? itemList : body + "\n" + itemList
            }
            content.body = body
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        if routine.alertMode == .alarm {
            content.interruptionLevel = .timeSensitive
        }
        content.userInfo = [
            "routineID": occurrence.routineID.uuidString,
            "dayKey": Scheduler.dayKey(for: occurrence.day),
            "slotMinutes": occurrence.slotMinutes,
            "alarm": routine.alertMode == .alarm,
            "title": routine.title,
        ]
        return content
    }

    private func makeSentinel() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Keep your reminders running")
        content.body = String(localized: "Open the app for a moment so it can schedule the next two weeks of reminders.")
        content.sound = nil
        let fireDate = Calendar.current.date(byAdding: .day, value: Self.horizonDays - 1, to: .now) ?? .now
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        comps.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: Self.sentinelID, content: content, trigger: trigger)
    }

    /// All identifiers an occurrence can own: base, nags, snooze, snooze-nags.
    private static func identifierFamily(for occurrenceID: String) -> [String] {
        var ids = [occurrenceID, "\(occurrenceID)-snooze"]
        for nag in 1...10 {
            ids.append("\(occurrenceID)-nag\(nag)")
            ids.append("\(occurrenceID)-snooze-nag\(nag)")
        }
        return ids
    }

    /// Cancels pending AND delivered notifications for one occurrence,
    /// e.g. after it is marked done.
    func cancel(occurrenceID: String) {
        let ids = Self.identifierFamily(for: occurrenceID)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Completion from notification actions

    private func markDone(routineID: UUID, dayKey: String, slotMinutes: Int) {
        guard let container else { return }
        let context = container.mainContext
        guard let record = CompletionStore.record(for: routineID, dayKey: dayKey, slotMinutes: slotMinutes,
                                                  in: context, createIfMissing: true) else { return }
        let wasDone = record.isDone
        record.isDone = true
        record.completedAt = .now
        // Mirror the in-app behavior: banner-done checks every checklist item.
        let routineDescriptor = FetchDescriptor<Routine>(predicate: #Predicate<Routine> { $0.id == routineID })
        if let routine = try? context.fetch(routineDescriptor).first {
            record.completedItemIDs = routine.items.map { $0.id }
        }
        try? context.save()
        if !wasDone { AppSettings.shared.awardCompletion() }
        cancel(occurrenceID: "\(routineID.uuidString)-\(dayKey)-\(slotMinutes)")
    }

    private func snooze(routineID: UUID, dayKey: String, slotMinutes: Int, title: String, isAlarm: Bool) {
        let occurrenceID = "\(routineID.uuidString)-\(dayKey)-\(slotMinutes)"
        // Snoozing replaces the whole alert chain: silence the current nags,
        // then re-alert (and re-nag, for alarm mode) after the snooze interval.
        cancel(occurrenceID: occurrenceID)

        let settings = AppSettings.shared
        let center = UNUserNotificationCenter.current()
        let userInfo: [String: Any] = [
            "routineID": routineID.uuidString, "dayKey": dayKey, "slotMinutes": slotMinutes,
            "alarm": isAlarm, "title": title,
        ]

        func snoozeContent(nagIndex: Int) -> UNMutableNotificationContent {
            let content = UNMutableNotificationContent()
            if settings.privateNotifications {
                content.title = String(localized: "Routine reminder")
                content.body = String(localized: "Open the app to see the details.")
            } else {
                content.title = nagIndex == 0 ? title : String(localized: "Still to do: \(title)")
                content.body = nagIndex == 0 ? String(localized: "Snoozed reminder") : ""
            }
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            if isAlarm { content.interruptionLevel = .timeSensitive }
            content.userInfo = userInfo
            return content
        }

        let snoozeSeconds = TimeInterval(max(1, settings.snoozeMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeSeconds, repeats: false)
        center.add(UNNotificationRequest(identifier: "\(occurrenceID)-snooze",
                                         content: snoozeContent(nagIndex: 0), trigger: trigger))
        if isAlarm {
            for nag in 1...max(1, settings.nagCount) {
                let interval = snoozeSeconds + TimeInterval(nag * settings.nagIntervalMinutes * 60)
                let nagTrigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(occurrenceID)-snooze-nag\(nag)",
                                                 content: snoozeContent(nagIndex: nag), trigger: nagTrigger))
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // While the user is actively in the app, follow-up nags go quietly to
        // the list instead of re-bannering every few minutes.
        if notification.request.identifier.contains("-nag") {
            return [.list]
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["routineID"] as? String,
              let routineID = UUID(uuidString: idString),
              let dayKey = userInfo["dayKey"] as? String,
              let slotMinutes = userInfo["slotMinutes"] as? Int else { return }
        let title = (userInfo["title"] as? String) ?? response.notification.request.content.title
        let isAlarm = (userInfo["alarm"] as? Bool) ?? false
        let actionID = response.actionIdentifier

        await MainActor.run {
            switch actionID {
            case Self.actionDone:
                self.markDone(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes)
            case Self.actionSnooze:
                self.snooze(routineID: routineID, dayKey: dayKey, slotMinutes: slotMinutes,
                            title: title, isAlarm: isAlarm)
            case UNNotificationDefaultActionIdentifier:
                // Tapping the body opens the app on that routine's day.
                let day = Calendar.current.startOfDay(for: .now)
                self.openRequest = OpenTarget(routineID: routineID, day: day)
            default:
                break
            }
        }
    }
}
