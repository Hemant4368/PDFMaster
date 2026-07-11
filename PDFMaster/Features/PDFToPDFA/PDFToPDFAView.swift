import SwiftData
import SwiftUI

struct PDFToPDFAView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Archival PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("Output name", text: $title)
            }

            Section {
                PrimaryButton(title: "Convert to PDF/A", systemImage: "archivebox") { convert() }
                    .disabled(sourceURL == nil)
            } footer: {
                Text("Creates an archival-grade PDF with embedded metadata. For full PDF/A-1b conformance, validate with Adobe Acrobat or a dedicated validator.")
            }
        }
        .navigationTitle("PDF to PDF/A")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting") } }
        .alert("PDF to PDF/A", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func convert() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.convertToPDFA(url: sourceURL)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
