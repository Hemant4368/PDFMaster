import SwiftUI

struct PDFToImageView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var exportedURLs: [URL] = []
    @State private var isWorking = false
    @State private var errorMessage: String?
    @AppStorage("pdfToImage.quality") private var quality: PDFQuality = .balanced
    @AppStorage("pdfToImage.format") private var format: PDFExportFormat = .jpg

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
            }
            if sourceURL != nil {
                Section("Output Options") {
                    Picker("Format", selection: $format) {
                        ForEach(PDFExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Quality", selection: $quality) {
                        ForEach(PDFQuality.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            Section {
                PrimaryButton(title: "Export Pages", systemImage: "photo.stack") { export() }
                    .disabled(sourceURL == nil)
            }
            if !exportedURLs.isEmpty {
                Section("Exports") {
                    ForEach(exportedURLs) { url in
                        ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .navigationTitle("PDF to Image")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Rendering pages") } }
        .alert("PDF to Image", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func export() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let pages = try await PDFProcessingService.shared.renderImages(from: sourceURL, format: format, scale: quality.renderScale)
                var urls: [URL] = []
                for (index, data) in pages.enumerated() {
                    let ext = format.rawValue.lowercased()
                    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sourceURL.displayTitle)-page-\(index + 1).\(ext)")
                    try data.write(to: fileURL, options: .atomic)
                    urls.append(fileURL)
                }
                exportedURLs = urls
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
