import SwiftData
import SwiftUI

struct CropPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var marginTop: CGFloat    = 0
    @State private var marginBottom: CGFloat = 0
    @State private var marginLeft: CGFloat   = 0
    @State private var marginRight: CGFloat  = 0
    @State private var title = "Cropped PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("Output name", text: $title)
            }

            Section("Crop Margins (points)") {
                marginRow(label: "Top",    value: $marginTop)
                marginRow(label: "Bottom", value: $marginBottom)
                marginRow(label: "Left",   value: $marginLeft)
                marginRow(label: "Right",  value: $marginRight)
            } footer: {
                Text("Cropping hides content using a crop box — it does not permanently remove page data.")
            }

            Section {
                PrimaryButton(title: "Crop PDF", systemImage: "crop") { crop() }
                    .disabled(sourceURL == nil)
            }
        }
        .navigationTitle("Crop PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Cropping PDF") } }
        .alert("Crop PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private func marginRow(label: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue)) pt").foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...200, step: 5)
        }
    }

    private func crop() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let margins = (top: marginTop, bottom: marginBottom, left: marginLeft, right: marginRight)
                let data = try await PDFProcessingService.shared.cropPages(url: sourceURL, margins: margins)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
