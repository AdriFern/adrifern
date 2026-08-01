import SwiftUI

struct MainTabView: View {
    @State private var showingQuickAdd = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle.portrait") }
            ContextsView()
                .tabItem { Label("People & Pets", systemImage: "figure.2.and.child.holdinghands") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Routine.self, ChecklistItem.self, ContextTag.self, CompletionRecord.self], inMemory: true)
}
