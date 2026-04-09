import SwiftUI

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Hashable {
    case interior = "Interior"
    case roof = "Roof"
}

// MARK: - Element Shape

enum ElementShape: String, CaseIterable {
    case rectangular = "Rectangular"
    case lShaped = "L-Shaped"
    case circular = "Circular"
}

// MARK: - Element Category

enum ElementCategory: String, CaseIterable, Identifiable {
    // Interior
    case bed = "Bed"
    case dinette = "Dinette"
    case desk = "Desk"
    case overhead = "Overhead"
    case wardrobe = "Wardrobe"
    // Roof
    case fan = "Fan"
    case solarPanel = "Solar Panel"

    var id: String { rawValue }

    var isRoofElement: Bool { self == .fan || self == .solarPanel }

    var color: Color {
        switch self {
        case .bed:        return Color.blue
        case .dinette:    return Color.orange
        case .desk:       return Color.purple
        case .overhead:   return Color.brown
        case .wardrobe:   return Color(red: 0.0, green: 0.6, blue: 0.6)
        case .fan:        return Color.cyan
        case .solarPanel: return Color(red: 0.9, green: 0.75, blue: 0.0)
        }
    }

    var icon: String {
        switch self {
        case .bed:        return "bed.double.fill"
        case .dinette:    return "fork.knife"
        case .desk:       return "laptopcomputer"
        case .overhead:   return "archivebox.fill"
        case .wardrobe:   return "tshirt.fill"
        case .fan:        return "wind"
        case .solarPanel: return "sun.max.fill"
        }
    }

    var allowedShapes: [ElementShape] {
        switch self {
        case .fan:     return [.rectangular, .circular]
        case .dinette: return [.rectangular, .lShaped]
        default:       return [.rectangular]
        }
    }

    var presets: [(name: String, widthCm: Double, lengthCm: Double)] {
        switch self {
        case .bed:
            // Transversal bed: widthCm = van interior width (~177), lengthCm = mattress depth
            return [
                ("140/180", 177, 140),
                ("150/180", 177, 150),
                ("160/180", 177, 160),
            ]
        case .dinette:
            return [
                ("Small L",  120, 50),
                ("Medium L", 150, 55),
                ("Large L",  170, 60),
            ]
        case .desk:
            return [
                ("Compact",  90, 55),
                ("Standard", 110, 60),
                ("Wide",     140, 65),
            ]
        case .overhead:
            return [
                ("Narrow",   80, 35),
                ("Standard", 100, 40),
                ("Wide",     120, 45),
            ]
        case .wardrobe:
            return [
                ("Compact",  55, 55),
                ("Standard", 60, 65),
                ("Large",    70, 75),
            ]
        case .fan:
            return [
                ("Mini 28cm",     28, 28),
                ("Standard 40cm", 40, 40),
                ("Maxxair 50cm",  50, 50),
            ]
        case .solarPanel:
            return [
                ("100W (56×99cm)",   56,  99),
                ("200W (68×150cm)",  68, 150),
                ("400W (100×168cm)", 100, 168),
            ]
        }
    }

    var defaultArm2WidthCm: Double {
        switch self {
        case .dinette: return 55
        default:       return 60
        }
    }

    var defaultArm2LengthCm: Double {
        switch self {
        case .dinette: return 80
        default:       return 60
        }
    }
}

// MARK: - Van Element

struct VanElement: Identifiable, Equatable {
    var id = UUID()
    var category: ElementCategory
    var name: String
    var widthCm: Double   // horizontal extent (across van width axis)
    var lengthCm: Double  // vertical extent (along van length axis)
    var shape: ElementShape = .rectangular
    // Centre of bounding box in van coordinate space (origin = van top-left)
    var positionCm: CGPoint
    var rotation: Double = 0  // reserved for future use

    // L-shape: second arm extends down-right from the main rectangle
    var arm2WidthCm: Double = 60
    var arm2LengthCm: Double = 80

    static func == (lhs: VanElement, rhs: VanElement) -> Bool { lhs.id == rhs.id }

    // Bounding box dimensions (used for clamping during drag)
    var boundingBoxWidthCm: Double { widthCm }
    var boundingBoxLengthCm: Double {
        shape == .lShaped ? lengthCm + arm2LengthCm : lengthCm
    }
}

// MARK: - Van Dimensions  (Peugeot Boxer L2H2)

enum VanSpec {
    static let interiorWidthCm:  Double = 177
    static let interiorLengthCm: Double = 304

    // Roof exterior usable area (between gutters, full length)
    static let roofWidthCm:  Double = 200
    static let roofLengthCm: Double = 385

    // Wheel-arch position (from front, fraction of length)
    static let wheelArchFrontFraction: Double = 0.60
    // Wheel-arch inset from side wall (fraction of width)
    static let wheelArchInsetFraction: Double = 0.11
    // Wheel-arch length (fraction of total van length)
    static let wheelArchLengthFraction: Double = 0.09
}
