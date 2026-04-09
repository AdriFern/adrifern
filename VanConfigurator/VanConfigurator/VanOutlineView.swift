import SwiftUI

/// Draws the scaled top-down outline of the van (floor or roof).
struct VanOutlineView: View {
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let mode: ViewMode

    private var cornerRadius: CGFloat { mode == .interior ? 8 : 16 }
    private var fillColor: Color {
        mode == .interior
            ? Color(.systemGray6)
            : Color(red: 0.85, green: 0.90, blue: 0.85)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Van floor / roof background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fillColor)
                .frame(width: canvasWidth, height: canvasHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemGray2), lineWidth: 2)
                )

            gridLines
            if mode == .interior { wheelArches }
            if mode == .roof     { roofRibs }
            directionLabels
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped()
    }

    // MARK: - Grid (every 50 cm)

    private var gridLines: some View {
        Canvas { ctx, size in
            let vanW = CGFloat(mode == .interior ? VanSpec.interiorWidthCm  : VanSpec.roofWidthCm)
            let vanL = CGFloat(mode == .interior ? VanSpec.interiorLengthCm : VanSpec.roofLengthCm)
            let sx = size.width  / vanW
            let sy = size.height / vanL

            var path = Path()
            let step: CGFloat = 50

            var x: CGFloat = step
            while x < vanW {
                path.move(to: CGPoint(x: x * sx, y: 0))
                path.addLine(to: CGPoint(x: x * sx, y: size.height))
                x += step
            }
            var y: CGFloat = step
            while y < vanL {
                path.move(to: CGPoint(x: 0, y: y * sy))
                path.addLine(to: CGPoint(x: size.width, y: y * sy))
                y += step
            }
            ctx.stroke(path, with: .color(Color(.systemGray4).opacity(0.35)), lineWidth: 0.5)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    // MARK: - Wheel Arches (interior only)

    private var wheelArches: some View {
        let archY = canvasHeight * CGFloat(VanSpec.wheelArchFrontFraction)
        let archH = canvasHeight * CGFloat(VanSpec.wheelArchLengthFraction)
        let archW = canvasWidth  * CGFloat(VanSpec.wheelArchInsetFraction)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray4))
                .frame(width: archW, height: archH)
                .offset(x: 0, y: archY)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray4))
                .frame(width: archW, height: archH)
                .offset(x: canvasWidth - archW, y: archY)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    // MARK: - Roof Ribs (roof only)

    private var roofRibs: some View {
        Canvas { ctx, size in
            let ribCount = 4
            let spacing = size.height / CGFloat(ribCount + 1)
            for i in 1...ribCount {
                let y = spacing * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(Color(.systemGray3).opacity(0.5)), lineWidth: 1.5)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    // MARK: - Direction Labels

    private var directionLabels: some View {
        VStack {
            Text("▲ FRONT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(.systemGray))
                .padding(.top, 5)
            Spacer()
            Text("REAR ▼")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(.systemGray))
                .padding(.bottom, 5)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}
