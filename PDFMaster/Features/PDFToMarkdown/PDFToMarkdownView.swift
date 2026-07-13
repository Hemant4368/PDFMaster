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
    @AppStorage("pdfToMarkdown.detectHeadings") private var detectHeadings = true
    @AppStorage("pdfToMarkdown.detectTables") private var detectTables = true

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Convert to Markdown", systemImage: "chevron.left.forwardslash.chevron.right") { convert() }
                    .disabled(sourceURL == nil)
            }

            if sourceURL != nil {
                Section("Output Options") {
                    Toggle("Detect and format headings", isOn: $detectHeadings)
                    Toggle("Detect and format tables", isOn: $detectTables)
                }
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
                markdownText = MarkdownConverter.convert(rawText, detectHeadings: detectHeadings, detectTables: detectTables)
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
    static func convert(_ text: String, detectHeadings: Bool = true, detectTables: Bool = true) -> String {
        let rawLines = text.components(separatedBy: .newlines)
        var result: [String] = []
        var i = 0
        while i < rawLines.count {
            let line = rawLines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { result.append(""); i += 1; continue }

            if detectHeadings && trimmed.count < 70 && trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil {
                result.append("## \(trimmed.capitalized)")
                i += 1
                continue
            }

            if trimmed.hasPrefix("\u{2022}") || trimmed.hasPrefix("\u{00B7}") {
                result.append("- \(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))")
                i += 1
                continue
            }

            if detectTables {
                let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }
                if parts.count > 1 {
                    let headerRow = parts.map { "| \($0.trimmingCharacters(in: .whitespaces)) " }.joined() + "|"
                    let separatorRow = parts.map { _ in "| --- " }.joined() + "|"
                    result.append(headerRow)
                    result.append(separatorRow)
                    i += 1
                    while i < rawLines.count {
                        let next = rawLines[i].trimmingCharacters(in: .whitespaces)
                        if next.isEmpty || next == trimmed { break }
                        let rowParts = next.components(separatedBy: "  ").filter { !$0.isEmpty }
                        if rowParts.count < 2 { result.append(next); i += 1; break }
                        let row = rowParts.map { "| \($0.trimmingCharacters(in: .whitespaces)) " }.joined() + "|"
                        result.append(row)
                        i += 1
                    }
                    continue
                }
            }

            result.append(line)
            i += 1
        }
        return result.joined(separator: "\n")
    }
}
