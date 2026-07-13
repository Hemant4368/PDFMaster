import SwiftData
import SwiftUI
import UIKit

struct TxtToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Text PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @AppStorage("txtToPDF.fontFamily") private var fontFamily: TxtFontFamily = .systemDefault
    @AppStorage("txtToPDF.pageSize") private var pageSize: PDFPageSize = .a4
    @AppStorage("txtToPDF.margin") private var margin: PDFMarginSize = .small
    @AppStorage("txtToPDF.fontSize") private var fontSize: Double = 12

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose Text File (.txt)") {
                    showPicker = true
                }
                if let url = sourceURL { SelectedPDFPreview(url: url) }
            }

            Section("Text Settings") {
                TextField("Output name", text: $title)
                Picker("Font", selection: $fontFamily) {
                    ForEach(TxtFontFamily.allCases) { f in Text(f.rawValue).tag(f) }
                }
                Stepper("Font size: \(Int(fontSize))pt", value: $fontSize, in: 8...24, step: 1)
            }

            Section("Page Settings") {
                Picker("Page Size", selection: $pageSize) {
                    ForEach(PDFPageSize.allCases) { s in Text(s.rawValue).tag(s) }
                }
                Picker("Margin", selection: $margin) {
                    ForEach(PDFMarginSize.allCases) { m in Text(m.rawValue).tag(m) }
                }
            }

            Section {
                PrimaryButton(title: "Convert to PDF", systemImage: "doc.plaintext") { convert() }
                    .disabled(sourceURL == nil || title.isEmpty)
            }
        }
        .navigationTitle("Text to PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(contentTypes: [.plainText], allowsMultipleSelection: false) {
                sourceURL = $0.first
                if let name = $0.first?.deletingPathExtension().lastPathComponent { title = name }
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to PDF") } }
        .alert("Text to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { if let url = shareInbox.consumeURL(for: .txtToPDF) { sourceURL = url } }
    }

    private func convert() {
        guard let url = sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let data = try TextPDFRenderer.render(text: text, fontFamily: fontFamily, fontSize: CGFloat(fontSize), margin: margin)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: – Renderer

enum TextPDFRenderer {
    static func render(text: String, fontFamily: TxtFontFamily = .systemDefault, fontSize: CGFloat = 12, margin: PDFMarginSize = .small, isRTF: Bool = false) throws -> Data {
        let pageWidth: CGFloat  = 595.28
        let pageHeight: CGFloat = 841.89
        let marginPts: CGFloat  = margin.points + 48

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        let font: UIFont = {
            switch fontFamily {
            case .systemDefault: return .systemFont(ofSize: fontSize)
            case .courier:       return UIFont(name: "Courier", size: fontSize) ?? .systemFont(ofSize: fontSize)
            case .georgia:       return UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
            case .helvetica:     return UIFont(name: "Helvetica", size: fontSize) ?? .systemFont(ofSize: fontSize)
            }
        }()

        let attributes: [NSAttributedString.Key: Any] = [
            .font:            font,
            .foregroundColor: UIColor.black,
            .paragraphStyle:  paragraphStyle,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)

        let textRect = CGRect(x: marginPts, y: marginPts,
                              width: pageWidth - marginPts * 2,
                              height: pageHeight - marginPts * 2)

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var charIndex: CFIndex = 0
        let totalChars = attributed.length

        while charIndex < totalChars {
            UIGraphicsBeginPDFPage()
            guard let ctx = UIGraphicsGetCurrentContext() else { break }
            ctx.textMatrix = .identity
            ctx.translateBy(x: 0, y: pageHeight)
            ctx.scaleBy(x: 1, y: -1)

            let path = CGMutablePath()
            path.addRect(textRect)
            let range = CFRange(location: charIndex, length: 0)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, ctx)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            charIndex += visibleRange.length
            if visibleRange.length == 0 { break }
        }

        UIGraphicsEndPDFContext()
        guard pdfData.length > 0 else { throw PDFProcessingError.writeFailed }
        return pdfData as Data
    }
}
