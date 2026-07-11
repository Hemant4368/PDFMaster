import CoreGraphics
import Foundation
import SwiftUI

struct WatermarkOptions: Equatable {
    var text: String = "SAMPLE"
    var opacity: CGFloat = 0.22
    var rotation: CGFloat = -35
    var fontSize: CGFloat = 54
    var color: Color = AppTheme.primary
    var position: WatermarkPosition = .center
}

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case center = "Center"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    var id: String { rawValue }
}

enum PDFExportFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case png = "PNG"
    var id: String { rawValue }
}

enum PDFQuality: String, CaseIterable, Identifiable {
    case low = "Low"
    case balanced = "Balanced"
    case high = "High"
    var id: String { rawValue }

    var imageCompression: CGFloat {
        switch self {
        case .low: 0.45
        case .balanced: 0.72
        case .high: 0.95
        }
    }
}
