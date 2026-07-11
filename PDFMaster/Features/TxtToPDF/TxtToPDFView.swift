import SwiftData
import SwiftUI
import UIKit

struct TxtToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Text PDF"
    @State private var fontSize: CGFloat = 12
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose Text File (.txt)") {
                    showPicker = true
                }
                if let url = sourceURL { SelectedPDFPreview(url: url) }
            }

            Section("Options") {
                TextField("Output name", text: $title)
                Stepper("Font size: \(Int(fontSize))pt", value: $fontSize, in: 8...24, step: 1)
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
                let data = try TextPDFRenderer.render(text: text, fontSize: fontSize)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: – Renderer

enum TextPDFRenderer {
    static func render(text: String, fontSize: CGFloat = 12, isRTF: Bool = false) throws -> Data {
        let pageWidth: CGFloat  = 595.28
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat     = 48

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font:            UIFont(name: "Helvetica", size: fontSize) ?? .systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black,
            .paragraphStyle:  paragraphStyle,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)

        let textRect = CGRect(x: margin, y: margin,
                              width: pageWidth - margin * 2,
                              height: pageHeight - margin * 2)

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
