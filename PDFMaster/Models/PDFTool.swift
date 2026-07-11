import SwiftUI

enum PDFTool: String, CaseIterable, Identifiable {
    case scanner = "Scan"
    case imageToPDF = "Image to PDF"
    case pdfToImage = "PDF to Image"
    case merge = "Merge PDFs"
    case extract = "Extract Pages"
    case reorder = "Reorder Pages"
    case password = "Password"
    case watermark = "Watermark"
    case signature = "Signature"
    case annotation = "Annotate"
    case ocr = "OCR Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scanner: "viewfinder"
        case .imageToPDF: "photo.on.rectangle"
        case .pdfToImage: "photo.stack"
        case .merge: "square.stack.3d.down.forward"
        case .extract: "doc.on.doc"
        case .reorder: "arrow.up.arrow.down.square"
        case .password: "lock.shield"
        case .watermark: "doc.text.fill"
        case .signature: "signature"
        case .annotation: "pencil.and.outline"
        case .ocr: "text.viewfinder"
        }
    }

    var accent: Color {
        switch self {
        case .scanner, .password, .watermark: AppTheme.primary
        case .merge, .extract, .reorder: .orange
        case .signature, .annotation: .pink
        case .ocr: .blue
        case .imageToPDF, .pdfToImage: .green
        }
    }
}

enum AppTab: String, CaseIterable {
    case files = "My Files"
    case tools = "Tools"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .files: "doc.text"
        case .tools: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }
}
