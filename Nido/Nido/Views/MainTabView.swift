import SwiftUI

struct MainTabView: View {
    @Environment(FamilyStore.self) private var store
    @State private var joinSheetDismissed = false

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
        // Swiping down genuinely dismisses for this session; the join stays
        // pending and can be finished (or declined) from Settings.
        .sheet(isPresented: Binding(
            get: { store.pendingJoinFamilyID != nil && store.phase == .ready && !joinSheetDismissed },
            set: { if !$0 { joinSheetDismissed = true } }
        )) {
            NavigationStack {
                JoinProfileView()
            }
        }
        .onChange(of: store.pendingJoinFamilyID) { _, newValue in
            if newValue != nil { joinSheetDismissed = false }
        }
    }
}
