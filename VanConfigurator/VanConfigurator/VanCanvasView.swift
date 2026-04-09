import SwiftUI

/// Displays the scaled top-down van canvas and all placed elements.
struct VanCanvasView: View {
    let mode: ViewMode
    let onEditElement: (VanElement) -> Void

    @EnvironmentObject var viewModel: ConfigViewModel

    private var vanWidthCm:  Double {
        mode == .interior ? VanSpec.interiorWidthCm  : VanSpec.roofWidthCm
    }
    private var vanLengthCm: Double {
        mode == .interior ? VanSpec.interiorLengthCm : VanSpec.roofLengthCm
    }

    var body: some View {
        GeometryReader { geo in
            let (scale, canvasW, canvasH, offX, offY) = layout(in: geo.size)

            ZStack(alignment: .topLeading) {
                // Tapping blank canvas deselects
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.select(nil) }

                VanOutlineView(
                    canvasWidth: canvasW,
                    canvasHeight: canvasH,
                    mode: mode
                )
                .offset(x: offX, y: offY)

                rulerLabels(canvasW: canvasW, canvasH: canvasH,
                            offX: offX, offY: offY, scale: scale)

                ForEach(viewModel.elements(for: mode)) { element in
                    PlacedElementView(
                        element: element,
                        scale: scale,
                        vanOffsetX: offX,
                        vanOffsetY: offY,
                        vanWidthCm: vanWidthCm,
                        vanLengthCm: vanLengthCm,
                        mode: mode,
                        onEdit: onEditElement
                    )
                }

                if viewModel.elements(for: mode).isEmpty {
                    emptyHint(offX: offX, offY: offY, w: canvasW, h: canvasH)
                }
            }
        }
    }

    // MARK: - Layout

    private func layout(in size: CGSize) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        let padding: CGFloat = 24
        let availW = size.width  - padding * 2
        let availH = size.height - padding * 2
        let scale  = min(availW / CGFloat(vanWidthCm), availH / CGFloat(vanLengthCm))
        let w = CGFloat(vanWidthCm)  * scale
        let h = CGFloat(vanLengthCm) * scale
        let offX = (size.width  - w) / 2
        let offY = (size.height - h) / 2
        return (scale, w, h, offX, offY)
    }

    // MARK: - Ruler labels

    private func rulerLabels(
        canvasW: CGFloat, canvasH: CGFloat,
        offX: CGFloat, offY: CGFloat,
        scale: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // Width markers along bottom edge (every 50 cm)
            ForEach(makeStride(from: 50, through: vanWidthCm - 20, by: 50), id: \.self) { cm in
                Text("\(Int(cm))")
                    .font(.system(size: 8))
                    .foregroundColor(Color(.systemGray3))
                    .offset(x: offX + CGFloat(cm) * scale - 8,
                            y: offY + canvasH + 2)
            }
            // Length markers along right edge (every 50 cm)
            ForEach(makeStride(from: 50, through: vanLengthCm - 20, by: 50), id: \.self) { cm in
                Text("\(Int(cm))")
                    .font(.system(size: 8))
                    .foregroundColor(Color(.systemGray3))
                    .offset(x: offX + canvasW + 2,
                            y: offY + CGFloat(cm) * scale - 6)
            }
        }
    }

    // MARK: - Empty state

    private func emptyHint(offX: CGFloat, offY: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 32))
                .foregroundColor(Color(.systemGray4))
            Text("Tap an element below to configure and add it")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray3))
                .multilineTextAlignment(.center)
        }
        .offset(x: offX, y: offY)
        .frame(width: w, height: h)
    }
}

// MARK: - Helper

private func makeStride(from: Double, through: Double, by: Double) -> [Double] {
    var result: [Double] = []
    var v = from
    while v <= through {
        result.append(v)
        v += by
    }
    return result
}
