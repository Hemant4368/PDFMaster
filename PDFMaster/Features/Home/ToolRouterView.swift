import SwiftUI

struct ToolRouterView: View {
    let tool: PDFTool

    var body: some View {
        switch tool {
        case .scanner:
            ScannerFlowView()
        case .imageToPDF:
            ImageToPDFView()
        case .pdfToImage:
            PDFToImageView()
        case .merge:
            MergePDFView()
        case .extract:
            ExtractPagesView()
        case .reorder:
            ReorderPagesView()
        case .password:
            PasswordToolView()
        case .watermark:
            WatermarkToolView()
        case .signature:
            SignatureToolView()
        case .annotation:
            AnnotationToolView()
        case .ocr:
            OCRToolView()
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
