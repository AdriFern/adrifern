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
    }
}
