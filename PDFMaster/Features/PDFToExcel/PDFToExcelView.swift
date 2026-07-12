import PDFKit
import SwiftUI

struct PDFToExcelView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var csvText = ""
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var options = PDFToExcelOptions()

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Extract Table Data", systemImage: "chart.bar.doc.horizontal") { extract() }
                    .disabled(sourceURL == nil)
            } header: {
                Text("Input")
            } footer: {
                Text("Extracts text as CSV. Works best with PDFs containing tabular data.")
            }

            if sourceURL != nil {
                Section("Options") {
                    Picker("Delimiter", selection: $options.delimiter) {
                        ForEach(CSVDelimiter.allCases) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Picker("Page Range", selection: $options.pageRange) {
                        ForEach(PageRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }
            }

            if !csvText.isEmpty {
                Section("CSV Preview") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(String(csvText.prefix(800)))
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                }

                Section {
                    Button {
                        if let url = saveAsCSV() { exportURL = url; showShare = true }
                    } label: {
                        Label("Export as CSV (Excel-compatible)", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Open the CSV in Microsoft Excel, Numbers, or Google Sheets.")
                }
            }
        }
        .navigationTitle("PDF to Excel")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; csvText = "" }
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Extracting Data") } }
        .alert("PDF to Excel", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func extract() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let rawText: String
                if let pdf = PDFDocument(url: sourceURL), let text = pdf.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawText = text
                } else {
                    rawText = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: ["en-US"])
                }
                csvText = convertToCSV(rawText, delimiter: options.delimiter)
                if csvText.isEmpty { errorMessage = "No extractable data found in this PDF." }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func convertToCSV(_ text: String, delimiter: CSVDelimiter) -> String {
        let sep: String = {
            switch delimiter {
            case .comma:     return ","
            case .tab:       return "\t"
            case .semicolon: return ";"
            }
        }()
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                let cells = line.components(separatedBy: "  ").filter { !$0.isEmpty }
                return cells.count > 1
                    ? cells.map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }.joined(separator: sep)
                    : "\"\(line.trimmingCharacters(in: .whitespaces))\""
            }
            .joined(separator: "\n")
    }

    private func saveAsCSV() -> URL? {
        guard let name = sourceURL?.deletingPathExtension().lastPathComponent,
              let data = csvText.data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).csv")
        try? data.write(to: url, options: .atomic)
        return url
    }
}
