import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ConfigViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                LayoutEditorView(mode: .interior)
                    .navigationTitle("Van Interior")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { clearToolbarButton(mode: .interior) }
            }
            .tabItem { Label("Interior", systemImage: "car.side.fill") }

            NavigationStack {
                LayoutEditorView(mode: .roof)
                    .navigationTitle("Van Roof")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { clearToolbarButton(mode: .roof) }
            }
            .tabItem { Label("Roof", systemImage: "sun.max.fill") }
        }
        .environmentObject(viewModel)
    }

    @ToolbarContentBuilder
    private func clearToolbarButton(mode: ViewMode) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.clearAll(in: mode)
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.elements(for: mode).isEmpty)
        }
    }
}

#Preview {
    ContentView()
}
