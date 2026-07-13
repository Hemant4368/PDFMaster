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
    @AppStorage("pdfToExcel.delimiter") private var delimiter = ","
    @AppStorage("pdfToExcel.firstRowHeaders") private var firstRowHeaders = false
    @AppStorage("pdfToExcel.skipEmptyRows") private var skipEmptyRows = true

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
                Section("Output Options") {
                    Picker("Column Delimiter", selection: $delimiter) {
                        Text("Comma (,)").tag(",")
                        Text("Semicolon (;)").tag(";")
                        Text("Tab").tag("\t")
                    }
                    Toggle("First row as column headers", isOn: $firstRowHeaders)
                    Toggle("Skip empty rows", isOn: $skipEmptyRows)
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
                    if firstRowHeaders {
                        Text("First row will be treated as column headers.")
                    }
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
                csvText = convertToCSV(rawText)
                if csvText.isEmpty { errorMessage = "No extractable data found in this PDF." }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func convertToCSV(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .filter { !skipEmptyRows || !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                let cells = line.components(separatedBy: "  ").filter { !$0.isEmpty }
                return cells.count > 1
                    ? cells.map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }.joined(separator: delimiter)
                    : "\"\(line.trimmingCharacters(in: .whitespaces))\""
            }
        return lines.joined(separator: "\n")
    }

    private func saveAsCSV() -> URL? {
        guard let name = sourceURL?.deletingPathExtension().lastPathComponent,
              let data = csvText.data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).csv")
        try? data.write(to: url, options: .atomic)
        return url
    }
}
