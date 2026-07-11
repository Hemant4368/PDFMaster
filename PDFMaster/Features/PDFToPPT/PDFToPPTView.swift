import SwiftUI

struct PDFToPPTView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var slideURLs: [URL] = []
    @State private var showShare = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                PrimaryButton(title: "Export Slides", systemImage: "rectangle.on.rectangle.angled") { exportSlides() }
                    .disabled(sourceURL == nil)
            } footer: {
                Text("Each PDF page is exported as a JPG image. Open slides in PowerPoint or Keynote and insert the images.")
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
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first; slideURLs = [] }
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
                let imageDataList = try await PDFProcessingService.shared.renderImages(from: sourceURL, format: .jpg)
                let base = sourceURL.deletingPathExtension().lastPathComponent
                slideURLs = try imageDataList.enumerated().map { index, data in
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(base)-slide-\(index + 1).jpg")
                    try data.write(to: url, options: .atomic)
                    return url
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
