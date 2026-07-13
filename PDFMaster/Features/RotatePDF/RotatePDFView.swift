import PDFKit
import SwiftData
import SwiftUI

struct RotatePDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pageCount = 0
    @AppStorage("rotatePDF.rotation") private var rotation = 90
    @State private var selectedPages = Set<Int>()
    @State private var title = "Rotated PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false

    private var previewHash: Int {
        var h = Hasher()
        h.combine(rotation)
        h.combine(selectedPages)
        return h.finalize()
    }

    private var rotationLabel: String {
        switch rotation {
        case 90:  "90° Clockwise"
        case 180: "180°"
        case 270: "90° Counter-clockwise"
        default:  "\(rotation)°"
        }
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
            }

            if pageCount > 0 {
                Section("Rotation") {
                    Picker("Rotate", selection: $rotation) {
                        Text("90° Clockwise").tag(90)
                        Text("180°").tag(180)
                        Text("90° Counter-clockwise").tag(270)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text(selectedPages.isEmpty ? "All \(pageCount) pages will be rotated" : "\(selectedPages.count) page(s) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 14) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            if let sourceURL {
                                PageThumbnailChip(
                                    pdfURL: sourceURL,
                                    index: index,
                                    isSelected: selectedPages.contains(index)
                                ) {
                                    if selectedPages.contains(index) { selectedPages.remove(index) }
                                    else { selectedPages.insert(index) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text("Pages (tap to select, empty = all)") }
            }

            if let sourceURL {
                Section("Preview (\(rotationLabel))") {
                    LivePDFPreview(document: previewDocument, originalURL: sourceURL, isProcessing: isPreparingPreview)
                }
            }

            Section {
                PrimaryButton(title: "Rotate PDF", systemImage: "rotate.right") { rotate() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Rotate PDF")
        .task { if let url = shareInbox.consumeURL(for: .rotatePDF) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let u = urls.first, let pdf = PDFDocument(url: u) { pageCount = pdf.pageCount }
                selectedPages.removeAll()
            }
        }
        .task(id: previewHash) { await generatePreview() }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Rotating Pages") } }
        .alert("Rotate PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
            let indexes = selectedPages.isEmpty ? [0] : Array(selectedPages).filter { $0 == 0 }
            let data = try await PDFProcessingService.shared.rotatePages(url: tempURL, rotation: rotation, pageIndexes: indexes.isEmpty ? [0] : indexes)
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

    private func rotate() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let indexes = selectedPages.isEmpty ? Array(0..<pageCount) : Array(selectedPages)
                let data = try await PDFProcessingService.shared.rotatePages(url: sourceURL, rotation: rotation, pageIndexes: indexes)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
