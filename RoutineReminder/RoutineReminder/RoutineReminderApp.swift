import SwiftUI
import SwiftData

@main
struct RoutineReminderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var settings = AppSettings.shared
    @State private var storeRecovered = false

    let container: ModelContainer

    init() {
        let schema = Schema([Routine.self, ChecklistItem.self, ContextTag.self, CompletionRecord.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Never crash-loop with the user's data trapped inside: move the
            // damaged store aside (preserving it for recovery) and start fresh.
            Self.moveStoreAside()
            do {
                container = try ModelContainer(for: schema)
                _storeRecovered = State(initialValue: true)
            } catch {
                fatalError("Could not create model container: \(error)")
            }
        }
        NotificationManager.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasOnboarded {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(settings)
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(settings.theme.accent)
            .alert(String(localized: "Data recovered"), isPresented: $storeRecovered) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "The app's database couldn't be opened, so a fresh one was created. The previous file was preserved on disk with a .damaged extension."))
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.refreshAuthorizationStatus()
                NotificationManager.shared.syncAll()
            }
        }
    }

    /// Renames the default SwiftData store files so a fresh store can be
    /// created without destroying the (possibly recoverable) original.
    private static func moveStoreAside() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = support.appendingPathComponent(suffix)
            if fm.fileExists(atPath: url.path) {
                try? fm.moveItem(at: url, to: support.appendingPathComponent(suffix + ".damaged"))
            }
        }
    }
}
