import SwiftUI

/// A proportional preview of an element as it will appear on the canvas.
struct ElementPreviewView: View {
    let category: ElementCategory
    let widthCm: Double
    let lengthCm: Double
    let shape: ElementShape
    let arm2WidthCm: Double
    let arm2LengthCm: Double
    let name: String

    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 28
            let maxW = geo.size.width  - padding * 2
            let maxH = geo.size.height - padding * 2

            // Bounding box in cm
            let bbW = CGFloat(widthCm)
            let bbH = shape == .lShaped
                        ? CGFloat(lengthCm + arm2LengthCm)
                        : (shape == .circular ? CGFloat(widthCm) : CGFloat(lengthCm))

            let scale = min(maxW / bbW, maxH / bbH)

            let scaledW   = CGFloat(widthCm)    * scale
            let scaledH   = CGFloat(lengthCm)   * scale
            let scaledA2W = CGFloat(arm2WidthCm)  * scale
            let scaledA2H = CGFloat(arm2LengthCm) * scale

            let totalScaledW = scaledW
            let totalScaledH: CGFloat = {
                switch shape {
                case .lShaped:     return scaledH + scaledA2H
                case .circular:    return scaledW
                case .rectangular: return scaledH
                }
            }()

            let offX = (geo.size.width  - totalScaledW) / 2
            let offY = (geo.size.height - totalScaledH) / 2

            ZStack(alignment: .topLeading) {
                Color.clear

                // Main shape
                switch shape {
                case .rectangular:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(category.color.opacity(0.72))
                        .frame(width: scaledW, height: scaledH)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(category.color, lineWidth: 1))
                        .offset(x: offX, y: offY)

                case .circular:
                    Circle()
                        .fill(category.color.opacity(0.72))
                        .frame(width: scaledW, height: scaledW)
                        .overlay(Circle().stroke(category.color, lineWidth: 1))
                        .offset(x: offX, y: offY)

                case .lShaped:
                    // Main arm
                    RoundedRectangle(cornerRadius: 5)
                        .fill(category.color.opacity(0.72))
                        .frame(width: scaledW, height: scaledH)
                        .offset(x: offX, y: offY)
                    // Second arm (bottom-right)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(category.color.opacity(0.72))
                        .frame(width: scaledA2W, height: scaledA2H)
                        .offset(x: offX + scaledW - scaledA2W, y: offY + scaledH)
                }

                // Width annotation
                Text("\(Int(widthCm)) cm")
                    .font(.system(size: 9))
                    .foregroundColor(Color(.systemGray))
                    .offset(x: offX, y: max(0, offY - 15))

                // Length annotation
                Text("\(Int(lengthCm)) cm")
                    .font(.system(size: 9))
                    .foregroundColor(Color(.systemGray))
                    .rotationEffect(.degrees(-90))
                    .offset(x: max(0, offX - 22), y: offY + scaledH / 2)

                // Centre label
                if scaledW > 40 && scaledH > 24 {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: scaledW - 8, height: scaledH - 8)
                        .offset(x: offX + 4, y: offY + 4)
                }
            }
        }
    }
}
