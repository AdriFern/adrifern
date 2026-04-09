import SwiftUI

/// Sheet for editing an already-placed element's dimensions, shape, and name.
struct ElementEditSheet: View {
    let element: VanElement
    let mode: ViewMode

    @EnvironmentObject var viewModel: ConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var widthCm:    Double
    @State private var lengthCm:   Double
    @State private var shape:      ElementShape
    @State private var arm2WidthCm:  Double
    @State private var arm2LengthCm: Double
    @State private var elementName: String

    init(element: VanElement, mode: ViewMode) {
        self.element = element
        self.mode = mode
        _widthCm      = State(initialValue: element.widthCm)
        _lengthCm     = State(initialValue: element.lengthCm)
        _shape        = State(initialValue: element.shape)
        _arm2WidthCm  = State(initialValue: element.arm2WidthCm)
        _arm2LengthCm = State(initialValue: element.arm2LengthCm)
        _elementName  = State(initialValue: element.name)
    }

    private var category: ElementCategory { element.category }

    var body: some View {
        NavigationStack {
            Form {
                shapeSection
                dimensionsSection
                if shape == .lShaped { armSection }
                nameSection
                previewSection
                deleteSection
            }
            .navigationTitle("Edit \(category.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var shapeSection: some View {
        if category.allowedShapes.count > 1 {
            Section("Shape") {
                Picker("Shape", selection: $shape) {
                    ForEach(category.allowedShapes, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var dimensionsSection: some View {
        Section("Dimensions") {
            dimensionRow(
                label: shape == .circular ? "Diameter" : "Width",
                value: $widthCm, range: 20...210,
                hint: shape == .circular ? "cm ⌀" : "cm →"
            )
            if shape != .circular {
                dimensionRow(label: "Depth", value: $lengthCm,
                             range: 20...304, hint: "cm ↓")
            }
        }
    }

    private var armSection: some View {
        Section("Second Arm") {
            dimensionRow(label: "Arm Width",  value: $arm2WidthCm,  range: 20...150, hint: "cm →")
            dimensionRow(label: "Arm Depth",  value: $arm2LengthCm, range: 20...200, hint: "cm ↓")
        }
    }

    private var nameSection: some View {
        Section("Label") {
            TextField("Name", text: $elementName)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            ElementPreviewView(
                category: category,
                widthCm: widthCm,
                lengthCm: lengthCm,
                shape: shape,
                arm2WidthCm: arm2WidthCm,
                arm2LengthCm: arm2LengthCm,
                name: elementName
            )
            .frame(height: 140)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.remove(id: element.id, from: mode)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Remove Element", systemImage: "trash")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func dimensionRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(hint)")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(minWidth: 72, alignment: .trailing)
            }
            Slider(value: value, in: range, step: 5)
                .tint(category.color)
        }
        .padding(.vertical, 4)
    }

    private func saveAndDismiss() {
        var updated = element
        updated.name         = elementName.isEmpty ? category.rawValue : elementName
        updated.widthCm      = widthCm
        updated.lengthCm     = lengthCm
        updated.shape        = shape
        updated.arm2WidthCm  = arm2WidthCm
        updated.arm2LengthCm = arm2LengthCm
        viewModel.update(updated, in: mode)
        dismiss()
    }
}
