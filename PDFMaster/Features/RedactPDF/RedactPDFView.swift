import PDFKit
import SwiftData
import SwiftUI

struct RedactPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pageCount = 0
    @State private var pageIndex = 0
    @State private var regionX: String = "50"
    @State private var regionY: String = "100"
    @State private var regionW: String = "200"
    @State private var regionH: String = "30"
    @State private var regions: [(pageIndex: Int, rect: CGRect)] = []
    @State private var title = "Redacted PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false
    @AppStorage("redact.fillColor") private var fillColor: RedactionFillColor = .black

    private var previewHash: Int {
        var h = Hasher()
        h.combine(regions.count)
        for r in regions { h.combine(r.pageIndex); h.combine(r.rect.origin.x); h.combine(r.rect.origin.y); h.combine(r.rect.width); h.combine(r.rect.height) }
        return h.finalize()
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
            }

            if pageCount > 0, let url = sourceURL {
                Section("Preview") {
                    LivePDFPreview(document: previewDocument, originalURL: url, isProcessing: isPreparingPreview)
                }

                Section {
                    Picker("Redaction Color", selection: $fillColor) {
                        ForEach(RedactionFillColor.allCases) { c in
                            HStack {
                                Circle().fill(Color(c.uiColor)).frame(width: 16, height: 16)
                                Text(c.rawValue)
                            }.tag(c)
                        }
                    }
                }

                Section {
                    Stepper("Page \(pageIndex + 1) of \(pageCount)", value: $pageIndex, in: 0...(pageCount - 1))
                    coordinateRow(label: "X", value: $regionX)
                    coordinateRow(label: "Y", value: $regionY)
                    coordinateRow(label: "Width", value: $regionW)
                    coordinateRow(label: "Height", value: $regionH)
                    Button("Add Redaction") { addRegion() }
                        .foregroundStyle(AppTheme.primary)
                } header: {
                    Text("Add Redaction Region")
                } footer: {
                    Text("Coordinates are in PDF points from the top-left corner of the page.")
                }

                if !regions.isEmpty {
                    Section("Pending Redactions (\(regions.count))") {
                        ForEach(regions.indices, id: \.self) { i in
                            let r = regions[i]
                            HStack {
                                Text("Page \(r.pageIndex + 1)")
                                Spacer()
                                Text("(\(Int(r.rect.minX)), \(Int(r.rect.minY))) \(Int(r.rect.width))\u{00D7}\(Int(r.rect.height))")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .onDelete { regions.remove(atOffsets: $0) }
                    }

                    Section {
                        PrimaryButton(title: "Apply Redactions", systemImage: "rectangle.fill.on.rectangle.fill") {
                            applyRedactions()
                        }
                    }
                }
            }
        }
        .navigationTitle("Redact PDF")
        .toolbar { if !regions.isEmpty { EditButton() } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let u = urls.first, let pdf = PDFDocument(url: u) { pageCount = pdf.pageCount }
                regions = []
                pageIndex = 0
            }
        }
        .task(id: previewHash) { await generatePreview() }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Applying Redactions") } }
        .alert("Redact PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private func coordinateRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            TextField("0", text: value)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
            Text("pt").foregroundStyle(.secondary)
        }
    }

    private func addRegion() {
        guard let x = Double(regionX), let y = Double(regionY),
              let w = Double(regionW), let h = Double(regionH),
              w > 0, h > 0 else {
            errorMessage = "Enter valid positive numbers for all coordinates."
            return
        }
        regions.append((pageIndex: pageIndex, rect: CGRect(x: x, y: y, width: w, height: h)))
    }

    private func generatePreview() async {
        guard let url = sourceURL, !regions.isEmpty else { previewDocument = nil; return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }
        do {
            let tempDoc = firstPageOnly(url: url)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            try tempDoc?.dataRepresentation()?.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let previewRegions = regions.filter { $0.pageIndex == 0 }.map { (pageIndex: 0, rect: $0.rect) }
            let data = try await PDFProcessingService.shared.redact(url: tempURL, regions: previewRegions)
            previewDocument = PDFDocument(data: data)
        } catch {
            previewDocument = nil
        }
    }

    private func firstPageOnly(url: URL) -> PDFDocument? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let single = PDFDocument()
        single.insert(page, at: 0)
        return single
    }

    private func applyRedactions() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.redact(url: sourceURL, regions: regions)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
