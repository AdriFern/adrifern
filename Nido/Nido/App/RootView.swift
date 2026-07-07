import SwiftUI

struct RootView: View {
    @Environment(FamilyStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.phase {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .onboarding:
                OnboardingFlowView()
            case .ready:
                MainTabView()
            }
        }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
