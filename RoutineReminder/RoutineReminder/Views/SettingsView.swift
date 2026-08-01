import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var transferMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                reminderBehaviorSection
                appearanceSection
                backupSection
                aboutSection
            }
            .navigationTitle(String(localized: "Settings"))
            .onAppear { notifications.refreshAuthorizationStatus() }
            .fileExporter(isPresented: $showingExporter,
                          document: exportDocument,
                          contentType: .json,
                          defaultFilename: "RoutineReminder-backup") { result in
                if case .success = result {
                    transferMessage = String(localized: "Backup exported.")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .alert(transferMessage ?? "", isPresented: Binding(
                get: { transferMessage != nil },
                set: { if !$0 { transferMessage = nil } }
            )) {
                Button(String(localized: "OK"), role: .cancel) {}
            }
        }
    }

    // MARK: Sections

    private var notificationSection: some View {
        Section(String(localized: "Notifications")) {
            LabeledContent(String(localized: "Permission"), value: statusText)
            if notifications.authorizationStatus == .notDetermined {
                Button(String(localized: "Enable notifications")) {
                    notifications.requestAuthorization()
                }
            } else if notifications.authorizationStatus == .denied {
                Link(String(localized: "Open iOS Settings to allow notifications"),
                     destination: URL(string: UIApplication.openSettingsURLString)!)
            }
        }
    }

    private var reminderBehaviorSection: some View {
        Section {
            Picker(String(localized: "Snooze length"), selection: $settings.snoozeMinutes) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                    Text(String(localized: "\(minutes) min")).tag(minutes)
                }
            }
            Picker(String(localized: "Alarm re-alerts every"), selection: $settings.nagIntervalMinutes) {
                ForEach([3, 5, 10, 15], id: \.self) { minutes in
                    Text(String(localized: "\(minutes) min")).tag(minutes)
                }
            }
            Picker(String(localized: "Alarm re-alert count"), selection: $settings.nagCount) {
                ForEach([2, 3, 5, 8], id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            DatePicker(String(localized: "Any-time tasks remind at"),
                       selection: Binding(
                           get: {
                               Calendar.current.date(bySettingHour: settings.anyTimeReminderMinutes / 60,
                                                     minute: settings.anyTimeReminderMinutes % 60,
                                                     second: 0, of: .now) ?? .now
                           },
                           set: { settings.anyTimeReminderMinutes = $0.minutesFromMidnight }),
                       displayedComponents: .hourAndMinute)
            Toggle(String(localized: "Private notifications"), isOn: $settings.privateNotifications)
        } header: {
            Text(String(localized: "Reminders"))
        } footer: {
            Text(String(localized: "Private notifications hide routine names and checklist items from the lock screen — banners just say a routine needs you. Changes apply to newly scheduled reminders."))
        }
        .onChange(of: settings.snoozeMinutes) { NotificationManager.shared.syncAll() }
        .onChange(of: settings.nagIntervalMinutes) { NotificationManager.shared.syncAll() }
        .onChange(of: settings.nagCount) { NotificationManager.shared.syncAll() }
        .onChange(of: settings.anyTimeReminderMinutes) { NotificationManager.shared.syncAll() }
        .onChange(of: settings.privateNotifications) { NotificationManager.shared.syncAll() }
    }

    private var appearanceSection: some View {
        Section(String(localized: "Appearance & Rewards")) {
            Picker(String(localized: "Appearance"), selection: $settings.appearance) {
                ForEach(Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            NavigationLink {
                RewardsView()
            } label: {
                HStack {
                    Label(String(localized: "Rewards"), systemImage: "sparkles")
                    Spacer()
                    Text(String(localized: "\(settings.rewardPoints) points"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label(String(localized: "Export backup"), systemImage: "square.and.arrow.up")
            }
            Button {
                showingImporter = true
            } label: {
                Label(String(localized: "Import backup"), systemImage: "square.and.arrow.down")
            }
        } header: {
            Text(String(localized: "Backup"))
        } footer: {
            Text(String(localized: "Your routines, people & pets, and history as a single file you control. Importing merges — it never deletes anything."))
        }
    }

    private var aboutSection: some View {
        Section {
            Label {
                Text(String(localized: "Alarm-mode reminders are time-sensitive alerts that can break through Focus (when Time Sensitive notifications are allowed) and re-alert until marked done, per your settings above. They follow the ring/silent switch."))
            } icon: {
                Image(systemName: "alarm")
            }
            .font(.footnote)
            Label {
                Text(String(localized: "The app itself makes no network connections — no accounts, no analytics, nothing uploaded. Your data stays on this device, leaving it only through your own iCloud/device backups and exports."))
            } icon: {
                Image(systemName: "lock.shield")
            }
            .font(.footnote)
            Label {
                Text(String(localized: "RoutineReminder is a general-purpose reminder tool, not a medical device. iOS may delay or suppress notifications — please don't rely on it as your only reminder for critical medication."))
            } icon: {
                Image(systemName: "stethoscope")
            }
            .font(.footnote)
        } header: {
            Text(String(localized: "About"))
        }
    }

    // MARK: Actions

    private func exportBackup() {
        if let data = try? BackupManager.export(from: modelContext) {
            exportDocument = BackupDocument(data: data)
            showingExporter = true
        } else {
            transferMessage = String(localized: "Export failed. Please try again.")
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try BackupManager.importBackup(data, into: modelContext)
            NotificationManager.shared.syncAll()
            transferMessage = String(localized: "Backup imported.")
        } catch {
            transferMessage = String(localized: "Couldn't read that backup file.")
        }
    }

    private var statusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return String(localized: "Allowed")
        case .denied: return String(localized: "Denied")
        case .notDetermined: return String(localized: "Not asked yet")
        @unknown default: return String(localized: "Unknown")
        }
    }
}
