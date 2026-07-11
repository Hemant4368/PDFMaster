import PDFKit
import SwiftUI

struct PDFToWordView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var extractedText = ""
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Extract Text", systemImage: "doc.text") { extract() }
                    .disabled(sourceURL == nil)
            }

            if !extractedText.isEmpty {
                Section("Extracted Text") {
                    TextEditor(text: $extractedText)
                        .font(.system(.callout))
                        .frame(minHeight: 200)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = extractedText
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }

                    Button {
                        if let url = saveAsRTF() { exportURL = url; showShare = true }
                    } label: {
                        Label("Export as RTF (Word-compatible)", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("RTF files can be opened and edited in Microsoft Word, Pages, and most word processors.")
                }
            }
        }
        .navigationTitle("PDF to Word")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; extractedText = "" }
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Extracting Text") } }
        .alert("PDF to Word", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func extract() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                if let pdf = PDFDocument(url: sourceURL), let text = pdf.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    extractedText = text
                } else {
                    extractedText = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: ["en-US"])
                }
                if extractedText.isEmpty { errorMessage = "No text found in this PDF." }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func saveAsRTF() -> URL? {
        guard let name = sourceURL?.deletingPathExtension().lastPathComponent else { return nil }
        let attributed = NSAttributedString(string: extractedText, attributes: [
            .font: UIFont.systemFont(ofSize: 12)
        ])
        guard let rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).rtf")
        try? rtfData.write(to: url, options: .atomic)
        return url
    }
}
