import PDFKit
import SwiftUI

struct PDFToMarkdownView: View {
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var markdownText = ""
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Convert to Markdown", systemImage: "chevron.left.forwardslash.chevron.right") { convert() }
                    .disabled(sourceURL == nil)
            }

            if !markdownText.isEmpty {
                Section("Markdown Preview") {
                    TextEditor(text: $markdownText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 260)
                }

                Section {
                    Button {
                        if let url = saveMarkdownFile() { exportURL = url; showShare = true }
                    } label: {
                        Label("Export as .md file", systemImage: "square.and.arrow.up")
                    }

                    ShareLink(item: markdownText) {
                        Label("Share Text", systemImage: "doc.on.doc")
                    }

                    Button { UIPasteboard.general.string = markdownText } label: {
                        Label("Copy Markdown", systemImage: "doc.on.clipboard")
                    }
                }
            }
        }
        .navigationTitle("PDF to Markdown")
        .task { if let url = shareInbox.consumeURL(for: .pdfToMarkdown) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; markdownText = "" }
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to Markdown") } }
        .alert("PDF to Markdown", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func convert() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let rawText: String
                if let pdf = PDFDocument(url: sourceURL),
                   let text = pdf.string,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawText = text
                } else {
                    rawText = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: ["en-US"])
                }
                markdownText = MarkdownConverter.convert(rawText)
                if markdownText.isEmpty { errorMessage = "No text found in this PDF." }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func saveMarkdownFile() -> URL? {
        guard let name = sourceURL?.deletingPathExtension().lastPathComponent,
              let data = markdownText.data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).md")
        try? data.write(to: url, options: .atomic)
        return url
    }
}

private enum MarkdownConverter {
    static func convert(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }
            if trimmed.count < 70 && trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil {
                return "## \(trimmed.capitalized)"
            }
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("·") {
                return "- \(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))"
            }
            return line
        }
        .joined(separator: "\n")
    }
}
