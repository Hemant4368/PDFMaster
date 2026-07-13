import PDFKit
import SwiftData
import SwiftUI

struct PDFFormsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var reloadToken = UUID()
    @State private var title = "Filled Form"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @AppStorage("forms.flattenOnExport") private var flattenOnExport = true
    @AppStorage("forms.highlightFields") private var highlightFields = true

    var body: some View {
        VStack(spacing: 0) {
            if let pdfDocument {
                EditablePDFKitView(document: pdfDocument, currentPageIndex: $currentPageIndex, reloadToken: reloadToken)
                    .ignoresSafeArea(edges: .bottom)

                formActionBar
            } else {
                Form {
                    Section {
                        Button("Choose PDF with Form Fields") { showPicker = true }
                        if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                    } footer: {
                        Text("Open a PDF containing AcroForm fields. Tap the fields in the preview to fill them in.")
                    }
                }
            }
        }
        .navigationTitle("PDF Forms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if sourceURL != nil {
                    Button("Choose File") { showPicker = true }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                if let u = urls.first {
                    sourceURL = u
                    pdfDocument = PDFDocument(url: u)
                    reloadToken = UUID()
                    title = u.displayTitle
                }
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Saving Form") } }
        .alert("PDF Forms", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var formActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                TextField("Output name", text: $title)
                    .textFieldStyle(.roundedBorder)
                PrimaryButton(title: "Save", systemImage: "tray.and.arrow.down.fill") { saveForm() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private func saveForm() {
        guard let pdfDocument else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                guard let data = pdfDocument.dataRepresentation() else { throw PDFProcessingError.writeFailed }
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
