import PDFKit
import SwiftData
import SwiftUI

struct CropPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Cropped PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var pageIndex = 0
    @State private var pageCount = 0
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false
    @AppStorage("crop.marginTop") private var marginTop: Double = 0
    @AppStorage("crop.marginBottom") private var marginBottom: Double = 0
    @AppStorage("crop.marginLeft") private var marginLeft: Double = 0
    @AppStorage("crop.marginRight") private var marginRight: Double = 0
    @AppStorage("crop.applyToAll") private var applyToAll = true

    private var previewHash: Int {
        var h = Hasher()
        h.combine(marginTop); h.combine(marginBottom); h.combine(marginLeft); h.combine(marginRight)
        return h.finalize()
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
            }

            Section {
                marginRow(label: "Top",    value: $marginTop)
                marginRow(label: "Bottom", value: $marginBottom)
                marginRow(label: "Left",   value: $marginLeft)
                marginRow(label: "Right",  value: $marginRight)
            } header: {
                Text("Crop Margins (points)")
            } footer: {
                Text("Cropping hides content using a crop box — it does not permanently remove page data.")
            }

            Section("Options") {
                Toggle("Apply crop to all pages", isOn: $applyToAll)
                if !applyToAll, pageCount > 0 {
                    Stepper("Page \(pageIndex + 1) of \(pageCount)", value: $pageIndex, in: 0...(pageCount - 1))
                }
            }

            if let sourceURL {
                Section("Preview") {
                    LivePDFPreview(document: previewDocument, originalURL: sourceURL, isProcessing: isPreparingPreview)
                }
            }

            Section {
                PrimaryButton(title: "Crop PDF", systemImage: "crop") { crop() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Crop PDF")
        .task(id: previewHash) { await generatePreview() }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet {
                sourceURL = $0.first
                if let u = $0.first, let pdf = PDFDocument(url: u) { pageCount = pdf.pageCount }
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Cropping PDF") } }
        .alert("Crop PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private func marginRow(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue)) pt").foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...200, step: 5)
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
            let margins = (top: CGFloat(marginTop), bottom: CGFloat(marginBottom), left: CGFloat(marginLeft), right: CGFloat(marginRight))
            let data = try await PDFProcessingService.shared.cropPages(url: tempURL, margins: margins)
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

    private func crop() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let margins = (top: CGFloat(marginTop), bottom: CGFloat(marginBottom), left: CGFloat(marginLeft), right: CGFloat(marginRight))
                let data = try await PDFProcessingService.shared.cropPages(url: sourceURL, margins: margins)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
