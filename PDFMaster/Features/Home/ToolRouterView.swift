import SwiftUI

struct ToolRouterView: View {
    let tool: PDFTool

    var body: some View {
        switch tool {
        // ORGANIZE
        case .scanner:      ScannerFlowView()
        case .merge:        MergePDFView()
        case .split:        SplitPDFView()
        case .extract:      ExtractPagesView()
        case .removePages:  ExtractPagesView()
        case .reorder:      ReorderPagesView()
        // OPTIMIZE
        case .compress:     CompressPDFView()
        case .repair:       RepairPDFView()
        case .ocr:          OCRToolView()
        // CONVERT TO PDF
        case .imageToPDF:   ImageToPDFView()
        case .wordToPDF:    WordToPDFView()
        case .pptToPDF:     PPTToPDFView()
        case .excelToPDF:   ExcelToPDFView()
        case .htmlToPDF:    HTMLToPDFView()
        case .txtToPDF:     TxtToPDFView()
        case .rtfToPDF:     RtfToPDFView()
        // CONVERT FROM PDF
        case .pdfToImage:   PDFToImageView()
        case .pdfToWord:    PDFToWordView()
        case .pdfToPPT:     PDFToPPTView()
        case .pdfToExcel:   PDFToExcelView()
        case .pdfToPDFA:    PDFToPDFAView()
        // EDIT
        case .watermark:    WatermarkToolView()
        case .annotation:   AnnotationToolView()
        case .rotatePDF:    RotatePDFView()
        case .addPageNumbers: AddPageNumbersView()
        case .cropPDF:      CropPDFView()
        case .editPDF:      EditPDFRouterView()
        case .pdfForms:     PDFFormsView()
        // SECURITY
        case .password:     PasswordToolView()
        case .signature:    SignatureToolView()
        case .redactPDF:    RedactPDFView()
        case .comparePDF:   ComparePDFView()
        // INTELLIGENCE
        case .pdfToMarkdown: PDFToMarkdownView()
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
