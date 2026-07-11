import SwiftUI

enum ToolCategory: String, CaseIterable, Identifiable {
    case all          = "All"
    case organize     = "Organize"
    case optimize     = "Optimize"
    case convertTo    = "Convert To"
    case convertFrom  = "Convert From"
    case edit         = "Edit"
    case security     = "Security"
//    case intelligence = "Intelligence"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .all:          .primary
        case .organize:     AppTheme.primary
        case .security:     AppTheme.primary
        case .optimize:     .orange
        case .convertTo:    .purple
        case .convertFrom:  Color(red: 0.18, green: 0.72, blue: 0.72)
        case .edit:         .blue
//        case .intelligence: .green
        }
    }
}

enum PDFTool: String, CaseIterable, Identifiable {
    // ORGANIZE
    case scanner        = "Scan"
    case merge          = "Merge PDFs"
    case split          = "Split PDF"
    case extract        = "Extract Pages"
    case removePages    = "Remove Pages"
    case reorder        = "Reorder Pages"

    // OPTIMIZE
    case compress       = "Compress PDF"
    case repair         = "Repair PDF"
    case ocr            = "OCR Text"

    // CONVERT TO PDF
    case imageToPDF     = "Image to PDF"
    case wordToPDF      = "Word to PDF"
    case pptToPDF       = "PowerPoint to PDF"
    case excelToPDF     = "Excel to PDF"
    case htmlToPDF      = "HTML to PDF"

    // CONVERT FROM PDF
    case pdfToImage     = "PDF to Image"
    case pdfToWord      = "PDF to Word"
    case pdfToPPT       = "PDF to PowerPoint"
    case pdfToExcel     = "PDF to Excel"
    case pdfToPDFA      = "PDF to PDF/A"

    // EDIT
    case watermark      = "Watermark"
    case annotation     = "Annotate"
    case rotatePDF      = "Rotate PDF"
    case addPageNumbers = "Add Page Numbers"
    case cropPDF        = "Crop PDF"
    case editPDF        = "Edit PDF"
    case pdfForms       = "PDF Forms"

    // SECURITY
    case password       = "Password"
    case signature      = "Signature"
    case redactPDF      = "Redact PDF"
    case comparePDF     = "Compare PDF"

    // INTELLIGENCE
//    case aiSummarizer   = "AI Summarizer"
//    case translatePDF   = "Translate PDF"
//    case pdfToMarkdown  = "PDF to Markdown"

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .scanner, .merge, .split, .extract, .removePages, .reorder:
            return .organize
        case .compress, .repair, .ocr:
            return .optimize
        case .imageToPDF, .wordToPDF, .pptToPDF, .excelToPDF, .htmlToPDF:
            return .convertTo
        case .pdfToImage, .pdfToWord, .pdfToPPT, .pdfToExcel, .pdfToPDFA:
            return .convertFrom
        case .watermark, .annotation, .rotatePDF, .addPageNumbers, .cropPDF, .editPDF, .pdfForms:
            return .edit
        case .password, .signature, .redactPDF, .comparePDF:
            return .security
//        case .aiSummarizer, .translatePDF, .pdfToMarkdown:
//            return .intelligence
        }
    }

    var accent: Color { category.accent }

    var icon: String {
        switch self {
        // Organize
        case .scanner:        "viewfinder"
        case .merge:          "square.stack.3d.down.forward"
        case .split:          "scissors"
        case .extract:        "doc.on.doc"
        case .removePages:    "minus.rectangle"
        case .reorder:        "arrow.up.arrow.down.square"
        // Optimize
        case .compress:       "arrow.down.to.line.compact"
        case .repair:         "wrench.and.screwdriver"
        case .ocr:            "text.viewfinder"
        // Convert To PDF
        case .imageToPDF:     "photo.on.rectangle"
        case .wordToPDF:      "doc.richtext"
        case .pptToPDF:       "play.rectangle"
        case .excelToPDF:     "tablecells"
        case .htmlToPDF:      "globe"
        // Convert From PDF
        case .pdfToImage:     "photo.stack"
        case .pdfToWord:      "doc.text"
        case .pdfToPPT:       "rectangle.on.rectangle.angled"
        case .pdfToExcel:     "chart.bar.doc.horizontal"
        case .pdfToPDFA:      "archivebox"
        // Edit
        case .watermark:      "doc.text.fill"
        case .annotation:     "pencil.and.outline"
        case .rotatePDF:      "rotate.right"
        case .addPageNumbers: "textformat.123"
        case .cropPDF:        "crop"
        case .editPDF:        "square.and.pencil"
        case .pdfForms:       "list.clipboard"
        // Security
        case .password:       "lock.shield"
        case .signature:      "signature"
        case .redactPDF:      "rectangle.fill.on.rectangle.fill"
        case .comparePDF:     "arrow.left.arrow.right.square"
        // Intelligence
//        case .aiSummarizer:   "sparkles.rectangle.stack"
//        case .translatePDF:   "character.book.closed"
//        case .pdfToMarkdown:  "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum AppTab: String, CaseIterable {
    case files = "My Files"
    case tools = "Tools"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .files:    "doc.text"
        case .tools:    "square.grid.2x2"
        case .settings: "gearshape"
        }
    }
}
