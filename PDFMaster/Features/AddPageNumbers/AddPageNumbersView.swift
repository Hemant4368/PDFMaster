import PDFKit
import SwiftData
import SwiftUI

struct AddPageNumbersView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Numbered PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false
    @AppStorage("pageNumbers.startingNumber") private var startingNumber = 1
    @AppStorage("pageNumbers.fontSize") private var fontSize: Double = 12
    @AppStorage("pageNumbers.position") private var position: PageNumberPosition = .bottomCenter
    @AppStorage("pageNumbers.format") private var format: PageNumberFormat = .arabic

    private var previewHash: Int {
        var h = Hasher()
        h.combine(startingNumber); h.combine(fontSize); h.combine(position); h.combine(format)
        return h.finalize()
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
            }

            Section("Page Number Options") {
                Stepper("Start at page \(startingNumber)", value: $startingNumber, in: 1...999)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Font size: \(Int(fontSize)) pt")
                    Slider(value: $fontSize, in: 8...24, step: 1)
                }

                Picker("Position", selection: $position) {
                    ForEach(PageNumberPosition.allCases) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }

                Picker("Number Format", selection: $format) {
                    ForEach(PageNumberFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
            }

            if let sourceURL {
                Section("Preview") {
                    LivePDFPreview(document: previewDocument, originalURL: sourceURL, isProcessing: isPreparingPreview)
                }
            }

            Section {
                PrimaryButton(title: "Add Page Numbers", systemImage: "textformat.123") { addNumbers() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Add Page Numbers")
        .task(id: previewHash) { await generatePreview() }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Adding Page Numbers") } }
        .alert("Add Page Numbers", isPresented: .constant(errorMessage != nil)) {
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
            let data = try await PDFProcessingService.shared.addPageNumbers(
                url: tempURL, startingAt: startingNumber, fontSize: CGFloat(fontSize), position: position
            )
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

    private func addNumbers() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.addPageNumbers(
                    url: sourceURL,
                    startingAt: startingNumber,
                    fontSize: CGFloat(fontSize),
                    position: position
                )
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
