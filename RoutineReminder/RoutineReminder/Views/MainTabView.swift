import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label(String(localized: "Today"), systemImage: "checklist") }
                .tag(0)
            CalendarView()
                .tabItem { Label(String(localized: "Calendar"), systemImage: "calendar") }
                .tag(1)
            RoutinesView()
                .tabItem { Label(String(localized: "Routines"), systemImage: "list.bullet.rectangle.portrait") }
                .tag(2)
            ContextsView()
                .tabItem { Label(String(localized: "People & Pets"), systemImage: "figure.2.and.child.holdinghands") }
                .tag(3)
            SettingsView()
                .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape") }
                .tag(4)
        }
        .tint(settings.theme.accent)
        .onChange(of: notifications.openRequest) { _, request in
            // Tapping a notification body lands on Today, on the right day.
            if request != nil { selectedTab = 0 }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSettings.shared)
        .modelContainer(for: [Routine.self, ChecklistItem.self, ContextTag.self, CompletionRecord.self], inMemory: true)
}
