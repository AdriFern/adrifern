import SwiftUI

/// Sheet shown when tapping a palette item. Lets the user pick a preset or set
/// custom dimensions, then adds the element to the canvas centred in the van.
struct ElementConfigSheet: View {
    let category: ElementCategory
    let mode: ViewMode

    @EnvironmentObject var viewModel: ConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPresetIndex: Int? = 0
    @State private var widthCm:    Double
    @State private var lengthCm:   Double
    @State private var shape:      ElementShape
    @State private var arm2WidthCm:  Double
    @State private var arm2LengthCm: Double
    @State private var elementName: String

    init(category: ElementCategory, mode: ViewMode) {
        self.category = category
        self.mode = mode
        let preset = category.presets.first
        _widthCm      = State(initialValue: preset?.widthCm  ?? 100)
        _lengthCm     = State(initialValue: preset?.lengthCm ?? 60)
        _shape        = State(initialValue: category.allowedShapes.first ?? .rectangular)
        _arm2WidthCm  = State(initialValue: category.defaultArm2WidthCm)
        _arm2LengthCm = State(initialValue: category.defaultArm2LengthCm)
        _elementName  = State(initialValue: preset?.name ?? category.rawValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                presetsSection
                shapeSection
                dimensionsSection
                if shape == .lShaped { armSection }
                nameSection
                previewSection
            }
            .navigationTitle("Configure \(category.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var presetsSection: some View {
        if !category.presets.isEmpty {
            Section("Presets") {
                ForEach(Array(category.presets.enumerated()), id: \.offset) { idx, preset in
                    Button {
                        selectedPresetIndex = idx
                        widthCm     = preset.widthCm
                        lengthCm    = preset.lengthCm
                        elementName = preset.name
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).foregroundColor(.primary)
                                Text("\(Int(preset.widthCm)) × \(Int(preset.lengthCm)) cm")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedPresetIndex == idx {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                }
                Button {
                    selectedPresetIndex = nil
                } label: {
                    HStack {
                        Text("Custom…").foregroundColor(.primary)
                        Spacer()
                        if selectedPresetIndex == nil {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }

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
                .onChange(of: shape) { _, newShape in
                    if newShape == .lShaped { selectedPresetIndex = nil }
                }
            }
        }
    }

    private var dimensionsSection: some View {
        Section("Dimensions") {
            dimensionRow(
                label: shape == .circular ? "Diameter" : "Width",
                value: $widthCm,
                range: widthRange,
                hint: shape == .circular ? "cm ⌀" : "cm →"
            )
            if shape != .circular {
                dimensionRow(label: "Depth", value: $lengthCm,
                             range: lengthRange, hint: "cm ↓")
            }
        }
        .onChange(of: widthCm)  { _, _ in selectedPresetIndex = nil }
        .onChange(of: lengthCm) { _, _ in selectedPresetIndex = nil }
    }

    private var armSection: some View {
        Section("Second Arm (L-shape)") {
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
            .frame(height: 160)
        }
    }

    // MARK: - Ranges

    private var widthRange: ClosedRange<Double> {
        switch category {
        case .bed:        return 140...200
        case .fan:        return 20...60
        case .solarPanel: return 40...150
        default:          return 30...177
        }
    }
    private var lengthRange: ClosedRange<Double> {
        switch category {
        case .bed:        return 100...210
        case .fan:        return 20...60
        case .solarPanel: return 60...250
        default:          return 20...304
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

    private func addAndDismiss() {
        let vanW = mode == .interior ? VanSpec.interiorWidthCm  : VanSpec.roofWidthCm
        let vanL = mode == .interior ? VanSpec.interiorLengthCm : VanSpec.roofLengthCm

        let element = VanElement(
            category:     category,
            name:         elementName.isEmpty ? category.rawValue : elementName,
            widthCm:      widthCm,
            lengthCm:     lengthCm,
            shape:        shape,
            positionCm:   CGPoint(x: CGFloat(vanW / 2), y: CGFloat(vanL / 2)),
            arm2WidthCm:  arm2WidthCm,
            arm2LengthCm: arm2LengthCm
        )
        viewModel.add(element, to: mode)
        viewModel.select(element.id)
        dismiss()
    }
}
