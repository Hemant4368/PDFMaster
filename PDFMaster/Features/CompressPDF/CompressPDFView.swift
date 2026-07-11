import PDFKit
import SwiftData
import SwiftUI

struct CompressPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var quality: PDFQuality = .low
    @State private var title = "Compressed PDF"
    @State private var originalSize: Int64 = 0
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var originalSizeLabel: String {
        originalSize > 0 ? ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file) : "—"
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                if originalSize > 0 {
                    LabeledContent("Original Size", value: originalSizeLabel)
                }
                TextField("Output name", text: $title)
            }

            Section("Compression Level") {
                Picker("Quality", selection: $quality) {
                    ForEach(PDFQuality.allCases) { q in Text(q.rawValue).tag(q) }
                }
                .pickerStyle(.segmented)
                Text(qualityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                PrimaryButton(title: "Compress PDF", systemImage: "arrow.down.to.line.compact") { compress() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Compress PDF")
        .task { if let url = shareInbox.consumeURL(for: .compress) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let u = urls.first,
                   let values = try? u.resourceValues(forKeys: [.fileSizeKey]) {
                    originalSize = Int64(values.fileSize ?? 0)
                }
                savedDocument = nil
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Compressing PDF") } }
        .alert("Compress PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var qualityDescription: String {
        switch quality {
        case .low:      "Smallest file — best for sharing"
        case .balanced: "Good quality with moderate size reduction"
        case .high:     "Near-original quality — minimal size reduction"
        }
    }

    private func compress() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.compress(url: sourceURL, quality: quality)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
