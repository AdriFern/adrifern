import SwiftUI

struct MainTabView: View {
    @Environment(FamilyStore.self) private var store

    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            RequestsView()
                .tabItem { Label("Requests", systemImage: "arrow.left.arrow.right.circle") }
                .badge(store.pendingIncoming.count)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // Joining an ADDITIONAL family (while others already exist) asks for
        // the name/color to use in that family without leaving the app.
        .sheet(isPresented: Binding(
            get: { store.pendingJoinFamilyID != nil && store.phase == .ready },
            set: { _ in /* dismissal keeps the join pending; it re-surfaces on next launch */ }
        )) {
            NavigationStack {
                JoinProfileView()
            }
        }
    }
}
