import SwiftUI
import Combine

class ConfigViewModel: ObservableObject {
    @Published var interiorElements: [VanElement] = []
    @Published var roofElements: [VanElement] = []
    @Published var selectedId: UUID? = nil

    // MARK: - Accessors

    func elements(for mode: ViewMode) -> [VanElement] {
        mode == .interior ? interiorElements : roofElements
    }

    // MARK: - Mutations

    func add(_ element: VanElement, to mode: ViewMode) {
        if mode == .interior {
            interiorElements.append(element)
        } else {
            roofElements.append(element)
        }
    }

    func remove(id: UUID, from mode: ViewMode) {
        if mode == .interior {
            interiorElements.removeAll { $0.id == id }
        } else {
            roofElements.removeAll { $0.id == id }
        }
        if selectedId == id { selectedId = nil }
    }

    func updatePosition(id: UUID, positionCm: CGPoint, in mode: ViewMode) {
        if mode == .interior {
            if let i = interiorElements.firstIndex(where: { $0.id == id }) {
                interiorElements[i].positionCm = positionCm
            }
        } else {
            if let i = roofElements.firstIndex(where: { $0.id == id }) {
                roofElements[i].positionCm = positionCm
            }
        }
    }

    func update(_ element: VanElement, in mode: ViewMode) {
        if mode == .interior {
            if let i = interiorElements.firstIndex(where: { $0.id == element.id }) {
                interiorElements[i] = element
            }
        } else {
            if let i = roofElements.firstIndex(where: { $0.id == element.id }) {
                roofElements[i] = element
            }
        }
    }

    func clearAll(in mode: ViewMode) {
        if mode == .interior { interiorElements.removeAll() }
        else { roofElements.removeAll() }
        selectedId = nil
    }

    func select(_ id: UUID?) {
        selectedId = id
    }
}
