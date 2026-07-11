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
    case topLeft     = "Top Left"
    case topRight    = "Top Right"
    case center      = "Center"
    case bottomLeft  = "Bottom Left"
    case bottomRight = "Bottom Right"
    var id: String { rawValue }
}

enum PDFExportFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case png = "PNG"
    var id: String { rawValue }
}

enum PDFQuality: String, CaseIterable, Identifiable {
    case low      = "Low"
    case balanced = "Balanced"
    case high     = "High"
    var id: String { rawValue }

    var imageCompression: CGFloat {
        switch self {
        case .low:      0.45
        case .balanced: 0.72
        case .high:     0.95
        }
    }

    var renderScale: CGFloat {
        switch self {
        case .low:      0.6
        case .balanced: 1.0
        case .high:     1.5
        }
    }
}

enum PDFPageOrientation: String, CaseIterable, Identifiable {
    case portrait = "Portrait", landscape = "Landscape"
    var id: String { rawValue }
}

enum PDFPageSize: String, CaseIterable, Identifiable {
    case a4 = "A4 (297×210 mm)", fit = "Fit", usLetter = "US Letter (215×279 mm)"
    var id: String { rawValue }

    func rect(orientation: PDFPageOrientation, imageSize: CGSize = .zero) -> CGRect {
        let base: CGSize
        switch self {
        case .a4:       base = CGSize(width: 595.28, height: 841.89)
        case .usLetter: base = CGSize(width: 612, height: 792)
        case .fit:
            let maxW: CGFloat = 595.28
            let scale = imageSize.width > 0 ? min(1, maxW / imageSize.width) : 1
            return CGRect(origin: .zero, size: CGSize(width: imageSize.width * scale, height: imageSize.height * scale))
        }
        switch orientation {
        case .portrait:
            let s = base.width <= base.height ? base : CGSize(width: base.height, height: base.width)
            return CGRect(origin: .zero, size: s)
        case .landscape:
            let s = base.width >= base.height ? base : CGSize(width: base.height, height: base.width)
            return CGRect(origin: .zero, size: s)
        }
    }
}

enum PDFMarginSize: String, CaseIterable, Identifiable {
    case none = "No margin", small = "Small", big = "Big"
    var id: String { rawValue }
    var points: CGFloat { switch self { case .none: 0; case .small: 18; case .big: 36 } }
}

enum HTMLScreenSize: String, CaseIterable, Identifiable {
    case yourScreen  = "Your screen"
    case desktopHD   = "Desktop HD (1920px)"
    case desktop     = "Desktop (1440px)"
    case tablet      = "Tablet (768px)"
    case mobile      = "Mobile (320px)"
    var id: String { rawValue }
    var width: CGFloat {
        switch self {
        case .yourScreen: return UIScreen.main.bounds.width
        case .desktopHD:  return 1920
        case .desktop:    return 1440
        case .tablet:     return 768
        case .mobile:     return 320
        }
    }
}

enum HTMLPageSize: String, CaseIterable, Identifiable {
    case a3       = "A3 (297×420 mm)"
    case a4       = "A4 (297×210 mm)"
    case a5       = "A5 (148×210 mm)"
    case usLetter = "US Letter (216×279 mm)"
    var id: String { rawValue }

    func paperRect(orientation: PDFPageOrientation) -> CGRect {
        let base: CGSize
        switch self {
        case .a3:       base = CGSize(width: 841.89, height: 1190.55)
        case .a4:       base = CGSize(width: 595.28, height: 841.89)
        case .a5:       base = CGSize(width: 419.53, height: 595.28)
        case .usLetter: base = CGSize(width: 612, height: 792)
        }
        switch orientation {
        case .portrait:
            let s = base.width <= base.height ? base : CGSize(width: base.height, height: base.width)
            return CGRect(origin: .zero, size: s)
        case .landscape:
            let s = base.width >= base.height ? base : CGSize(width: base.height, height: base.width)
            return CGRect(origin: .zero, size: s)
        }
    }
}

enum PageNumberPosition: String, CaseIterable, Identifiable {
    case bottomCenter = "Bottom Center"
    case bottomLeft   = "Bottom Left"
    case bottomRight  = "Bottom Right"
    case topCenter    = "Top Center"
    case topLeft      = "Top Left"
    case topRight     = "Top Right"
    var id: String { rawValue }
}
