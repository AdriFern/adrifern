import SwiftUI

/// Renders a single element that has been placed on the canvas.
/// Supports drag-to-reposition and tap-to-select/edit.
struct PlacedElementView: View {
    let element: VanElement
    let scale: CGFloat          // pts per cm
    let vanOffsetX: CGFloat
    let vanOffsetY: CGFloat
    let vanWidthCm: Double
    let vanLengthCm: Double
    let mode: ViewMode
    let onEdit: (VanElement) -> Void

    @EnvironmentObject var viewModel: ConfigViewModel
    @State private var isDragging = false
    @State private var dragStartCm: CGPoint = .zero   // CGFloat values in cm space

    private var isSelected: Bool { viewModel.selectedId == element.id }

    // Bounding-box centre in screen coordinates
    private var screenX: CGFloat { vanOffsetX + element.positionCm.x * scale }
    private var screenY: CGFloat { vanOffsetY + element.positionCm.y * scale }

    // Scaled element dimensions (pts)
    private var w:    CGFloat { CGFloat(element.widthCm)    * scale }
    private var h:    CGFloat { CGFloat(element.lengthCm)   * scale }
    private var arm2W: CGFloat { CGFloat(element.arm2WidthCm)  * scale }
    private var arm2H: CGFloat { CGFloat(element.arm2LengthCm) * scale }

    var body: some View {
        elementShape
            .position(x: screenX, y: screenY)
            .gesture(dragGesture)
            .onTapGesture {
                if isSelected { onEdit(element) }
                else          { viewModel.select(element.id) }
            }
            .contextMenu {
                Button { onEdit(element) } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    viewModel.remove(id: element.id, from: mode)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            .animation(.interactiveSpring(response: 0.25), value: isDragging)
            .zIndex(isDragging ? 10 : (isSelected ? 5 : 0))
    }

    // MARK: - Shape Rendering

    @ViewBuilder
    private var elementShape: some View {
        switch element.shape {
        case .rectangular: rectangularView
        case .lShaped:     lShapedView
        case .circular:    circularView
        }
    }

    private var rectangularView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(element.category.color.opacity(isDragging ? 0.88 : 0.72))
                .frame(width: w, height: h)
                .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            isSelected ? Color.white : element.category.color.opacity(0.9),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )

            elementLabel(boxW: w, boxH: h)
            if isSelected { deleteButton(boxW: w, boxH: h) }
        }
    }

    private var lShapedView: some View {
        // Bounding box: w × (h + arm2H)
        // Main arm:   top full-width strip (w × h)
        // Second arm: bottom-right corner  (arm2W × arm2H)
        let totalH = h + arm2H

        return ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                let c = element.category.color
                let alpha = isDragging ? 0.88 : 0.72

                let mainRect = CGRect(x: 0, y: 0, width: size.width, height: h)
                ctx.fill(Path(roundedRect: mainRect, cornerRadius: 5),
                         with: .color(c.opacity(alpha)))

                let armRect = CGRect(x: size.width - arm2W, y: h,
                                     width: arm2W, height: arm2H)
                ctx.fill(Path(roundedRect: armRect, cornerRadius: 5),
                         with: .color(c.opacity(alpha)))

                // Outline path
                var path = Path()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: h + arm2H))
                path.addLine(to: CGPoint(x: size.width - arm2W, y: h + arm2H))
                path.addLine(to: CGPoint(x: size.width - arm2W, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()

                ctx.stroke(path,
                           with: .color(isSelected ? .white : c.opacity(0.9)),
                           lineWidth: isSelected ? 2.5 : 1)
            }
            .frame(width: w, height: totalH)

            // Label in main arm
            elementLabel(boxW: w, boxH: h)
            if isSelected { deleteButton(boxW: w, boxH: totalH) }
        }
        .frame(width: w, height: totalH)
    }

    private var circularView: some View {
        let diameter = w
        return ZStack {
            Circle()
                .fill(element.category.color.opacity(isDragging ? 0.88 : 0.72))
                .frame(width: diameter, height: diameter)
                .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 6)
                .overlay(
                    Circle().stroke(
                        isSelected ? Color.white : element.category.color.opacity(0.9),
                        lineWidth: isSelected ? 2.5 : 1
                    )
                )

            elementLabel(boxW: diameter, boxH: diameter)
            if isSelected { deleteButton(boxW: diameter, boxH: diameter) }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func elementLabel(boxW: CGFloat, boxH: CGFloat) -> some View {
        if boxW > 32 && boxH > 20 {
            VStack(spacing: 1) {
                Text(element.name)
                    .font(.system(size: clampFont(min(boxW, boxH) * 0.17, lo: 7, hi: 11),
                                  weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if boxW > 50 && boxH > 34 {
                    Text("\(Int(element.widthCm))×\(Int(element.lengthCm)) cm")
                        .font(.system(size: clampFont(min(boxW, boxH) * 0.12, lo: 6, hi: 9)))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .frame(width: boxW - 6, height: boxH - 4)
        }
    }

    private func deleteButton(boxW: CGFloat, boxH: CGFloat) -> some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    viewModel.remove(id: element.id, from: mode)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.red))
                }
                .offset(x: 9, y: -9)
            }
            Spacer()
        }
        .frame(width: boxW, height: boxH)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartCm = element.positionCm
                    viewModel.select(element.id)
                }

                // value.translation is CGSize (CGFloat)
                let deltaX = value.translation.width  / scale
                let deltaY = value.translation.height / scale

                let halfW = CGFloat(element.boundingBoxWidthCm)  / 2
                let halfL = CGFloat(element.boundingBoxLengthCm) / 2
                let vanW  = CGFloat(vanWidthCm)
                let vanL  = CGFloat(vanLengthCm)

                let newX = (dragStartCm.x + deltaX).clamped(to: halfW...(vanW - halfW))
                let newY = (dragStartCm.y + deltaY).clamped(to: halfL...(vanL - halfL))

                viewModel.updatePosition(
                    id: element.id,
                    positionCm: CGPoint(x: newX, y: newY),
                    in: mode
                )
            }
            .onEnded { _ in isDragging = false }
    }
}

// MARK: - Helpers

private func clampFont(_ value: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
    min(max(value, lo), hi)
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
