import SwiftData
import SwiftUI
import UIKit

struct RtfToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "RTF PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose RTF File (.rtf)") {
                    showPicker = true
                }
                if let url = sourceURL { SelectedPDFPreview(url: url) }
            }

            Section("Options") {
                TextField("Output name", text: $title)
            }

            Section {
                PrimaryButton(title: "Convert to PDF", systemImage: "doc.richtext") { convert() }
                    .disabled(sourceURL == nil || title.isEmpty)
            }
        }
        .navigationTitle("RTF to PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(contentTypes: [.rtf], allowsMultipleSelection: false) {
                sourceURL = $0.first
                if let name = $0.first?.deletingPathExtension().lastPathComponent { title = name }
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to PDF") } }
        .alert("RTF to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { if let url = shareInbox.consumeURL(for: .rtfToPDF) { sourceURL = url } }
    }

    private func convert() {
        guard let url = sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try RtfPDFRenderer.render(url: url)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: – Renderer

enum RtfPDFRenderer {
    static func render(url: URL) throws -> Data {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        var docType: NSAttributedString.DocumentType = .rtf
        let ext = url.pathExtension.lowercased()
        if ext == "rtfd" { docType = .rtfd }

        guard let attributed = try? NSAttributedString(
            url: url,
            options: [.documentType: docType],
            documentAttributes: nil
        ) else { throw PDFProcessingError.unreadableDocument }

        let pageWidth: CGFloat  = 595.28
        let pageHeight: CGFloat = 841.89
        let margin: CGFloat     = 48
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

            let visible = CTFrameGetVisibleStringRange(frame)
            charIndex += visible.length
            if visible.length == 0 { break }
        }

        UIGraphicsEndPDFContext()
        guard pdfData.length > 0 else { throw PDFProcessingError.writeFailed }
        return pdfData as Data
    }
}
