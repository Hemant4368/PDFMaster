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
    @AppStorage("pdfToWord.exportFormat") private var exportFormat = "RTF"
    @AppStorage("pdfToWord.preserveParagraphs") private var preserveParagraphs = true

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Extract Text", systemImage: "doc.text") { extract() }
                    .disabled(sourceURL == nil)
            }

            if sourceURL != nil {
                Section("Output Options") {
                    Picker("Export Format", selection: $exportFormat) {
                        Text("RTF").tag("RTF")
                        Text("TXT").tag("TXT")
                    }
                    Toggle("Preserve paragraph breaks", isOn: $preserveParagraphs)
                }
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
                        if let url = saveExtractedText() { exportURL = url; showShare = true }
                    } label: {
                        Label("Export (\(exportFormat))", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text(exportFormat == "RTF"
                         ? "RTF files can be opened in Microsoft Word, Pages, and most word processors."
                         : "Plain text files can be opened in any text editor.")
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
                if !preserveParagraphs {
                    extractedText = extractedText.components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        .joined(separator: " ")
                }
                if extractedText.isEmpty { errorMessage = "No text found in this PDF." }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func saveExtractedText() -> URL? {
        guard let name = sourceURL?.deletingPathExtension().lastPathComponent else { return nil }
        if exportFormat == "RTF" {
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
        } else {
            guard let data = extractedText.data(using: .utf8) else { return nil }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).txt")
            try? data.write(to: url, options: .atomic)
            return url
        }
    }
}
