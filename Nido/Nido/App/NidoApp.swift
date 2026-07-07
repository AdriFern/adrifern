import SwiftUI

@main
struct NidoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = FamilyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .fontDesign(.rounded)
                .tint(.accentColor)
                .task {
                    AppDelegate.store = store
                    await store.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await store.refresh(silent: true) }
                    }
                }
        }
    }
}
