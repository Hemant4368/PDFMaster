import SwiftUI

struct PDFToPPTView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var slideURLs: [URL] = []
    @State private var showShare = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var options = PDFToPPTOptions()

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Export Slides", systemImage: "rectangle.on.rectangle.angled") { exportSlides() }
                    .disabled(sourceURL == nil)
            } header: {
                Text("Input")
            } footer: {
                Text("Each PDF page is exported as an image. Open slides in PowerPoint or Keynote and insert the images.")
            }

            if sourceURL != nil {
                Section("Options") {
                    Picker("Image Format", selection: $options.imageFormat) {
                        ForEach(PDFExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    Picker("Quality", selection: $options.quality) {
                        ForEach(PDFQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    Picker("Page Range", selection: $options.pageRange) {
                        ForEach(PageRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }
            }

            if !slideURLs.isEmpty {
                Section("Slide Images (\(slideURLs.count))") {
                    Button {
                        showShare = true
                    } label: {
                        Label("Share All \(slideURLs.count) Slides", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .navigationTitle("PDF to PowerPoint")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; slideURLs = [] }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: slideURLs)
        }
        .overlay { if isWorking { LoadingOverlay(title: "Exporting Slides") } }
        .alert("PDF to PowerPoint", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func exportSlides() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let imageDataList = try await PDFProcessingService.shared.renderImages(from: sourceURL, format: options.imageFormat)
                let base = sourceURL.deletingPathExtension().lastPathComponent
                let ext = options.imageFormat == .jpg ? "jpg" : "png"
                slideURLs = try imageDataList.enumerated().map { index, data in
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(base)-slide-\(index + 1).\(ext)")
                    try data.write(to: url, options: .atomic)
                    return url
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
