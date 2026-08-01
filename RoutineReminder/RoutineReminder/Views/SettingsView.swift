import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject private var notifications = NotificationManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    LabeledContent("Permission", value: statusText)
                    if notifications.authorizationStatus == .notDetermined {
                        Button("Enable notifications") {
                            notifications.requestAuthorization()
                        }
                    } else if notifications.authorizationStatus == .denied {
                        Link("Open iOS Settings to allow notifications",
                             destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
                Section {
                    Label {
                        Text("Alarm-mode reminders use time-sensitive alerts and re-notify every \(NotificationManager.nagInterval) minutes until marked done. For sound with Silent mode on, alerts still follow the ring/silent switch — consider a Focus exception for this app if you need to hear them.")
                    } icon: {
                        Image(systemName: "alarm")
                    }
                    .font(.footnote)
                } header: {
                    Text("About alarms")
                }
                Section {
                    Label {
                        Text("All data stays on this device. Quick Add parsing runs offline. Nothing is synced or shared.")
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                    .font(.footnote)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .onAppear { notifications.refreshAuthorizationStatus() }
        }
    }

    private var statusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
