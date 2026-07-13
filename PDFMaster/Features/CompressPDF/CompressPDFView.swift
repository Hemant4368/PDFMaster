import PDFKit
import SwiftData
import SwiftUI

struct CompressPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @AppStorage("compress.quality") private var quality: PDFQuality = .balanced
    @State private var title = "Compressed PDF"
    @State private var originalSize: Int64 = 0
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false

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

            if let sourceURL {
                Section("Preview (\(quality.rawValue))") {
                    LivePDFPreview(document: previewDocument, originalURL: sourceURL, isProcessing: isPreparingPreview)
                }
            }

            Section {
                PrimaryButton(title: "Compress PDF", systemImage: "arrow.down.to.line.compact") { compress() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Compress PDF")
        .task { if let url = shareInbox.consumeURL(for: .compress) { sourceURL = url } }
        .task(id: quality) { await generatePreview() }
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

    private func generatePreview() async {
        guard let url = sourceURL else { return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }
        do {
            let tempDoc = firstPageOnly(url: url)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            try tempDoc?.dataRepresentation()?.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let data = try await PDFProcessingService.shared.compress(url: tempURL, quality: quality)
            previewDocument = PDFDocument(data: data)
        } catch {
            previewDocument = PDFDocument(url: url)
        }
    }

    private func firstPageOnly(url: URL) -> PDFDocument? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let single = PDFDocument()
        single.insert(page, at: 0)
        return single
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
