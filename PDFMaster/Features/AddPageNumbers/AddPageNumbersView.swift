import SwiftData
import SwiftUI

struct AddPageNumbersView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var startingNumber = 1
    @State private var fontSize: CGFloat = 12
    @State private var position: PageNumberPosition = .bottomCenter
    @State private var title = "Numbered PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

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
            }

            Section {
                PrimaryButton(title: "Add Page Numbers", systemImage: "textformat.123") { addNumbers() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Add Page Numbers")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Adding Page Numbers") } }
        .alert("Add Page Numbers", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
                    fontSize: fontSize,
                    position: position
                )
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
