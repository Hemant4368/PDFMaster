import SwiftData
import SwiftUI

struct EditPDFRouterView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var importRange: PageRange = .all

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF to Edit") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
            } header: {
                Text("Input")
            } footer: {
                Text("Opens the PDF in the full editor — annotate, sign, add highlights, reorder or delete pages.")
            }

            if sourceURL != nil {
                Section("Options") {
                    Picker("Import", selection: $importRange) {
                        ForEach(PageRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }

                Section {
                    PrimaryButton(title: "Open in Editor", systemImage: "square.and.pencil") { openEditor() }
                }
            }
        }
        .navigationTitle("Edit PDF")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Importing PDF") } }
        .alert("Edit PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func openEditor() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try Data(contentsOf: sourceURL)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: sourceURL.displayTitle, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
