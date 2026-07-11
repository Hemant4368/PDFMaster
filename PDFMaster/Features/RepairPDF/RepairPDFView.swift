import SwiftData
import SwiftUI

struct RepairPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Repaired PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("Output name", text: $title)
            }

            Section {
                PrimaryButton(title: "Repair PDF", systemImage: "wrench.and.screwdriver") { repair() }
                    .disabled(sourceURL == nil)
            } footer: {
                Text("Repair attempts to fix structural corruption by re-writing the PDF. Severely damaged files may not be recoverable.")
            }
        }
        .navigationTitle("Repair PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Repairing PDF") } }
        .alert("Repair PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func repair() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.repair(url: sourceURL)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
