import SwiftUI

struct LayoutEditorView: View {
    let mode: ViewMode
    @EnvironmentObject var viewModel: ConfigViewModel

    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        VStack(spacing: 0) {
            VanCanvasView(mode: mode, onEditElement: { element in
                activeSheet = .edit(element)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))

            Divider()

            ElementPaletteView(mode: mode) { category in
                activeSheet = .configure(category)
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .configure(let category):
                ElementConfigSheet(category: category, mode: mode)
                    .environmentObject(viewModel)
            case .edit(let element):
                ElementEditSheet(element: element, mode: mode)
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Sheet routing

enum ActiveSheet: Identifiable {
    case configure(ElementCategory)
    case edit(VanElement)

    var id: String {
        switch self {
        case .configure(let c): return "cfg-\(c.id)"
        case .edit(let e):      return "edit-\(e.id)"
        }
    }
}
