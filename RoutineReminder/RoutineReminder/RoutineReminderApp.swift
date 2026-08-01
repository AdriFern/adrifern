import SwiftUI
import SwiftData

@main
struct RoutineReminderApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Routine.self, ChecklistItem.self, ContextTag.self, CompletionRecord.self)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        NotificationManager.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.refreshAuthorizationStatus()
                NotificationManager.shared.syncAll()
            }
        }
    }
}
