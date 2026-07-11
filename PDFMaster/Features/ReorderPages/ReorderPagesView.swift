import PDFKit
import SwiftData
import SwiftUI

struct ReorderPagesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var order: [Int] = []
    @State private var thumbnails: [UIImage] = []
    @State private var showPicker = false
    @State private var title = "Reordered PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("New PDF name", text: $title)
            }
            Section("Drag to reorder") {
                ForEach(order, id: \.self) { pageIndex in
                    HStack {
                        if thumbnails.indices.contains(pageIndex) {
                            Image(uiImage: thumbnails[pageIndex])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 46, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text("Page \(pageIndex + 1)")
                        Spacer()
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            Section {
                PrimaryButton(title: "Save Reordered PDF", systemImage: "arrow.up.arrow.down.square") { save() }
                    .disabled(sourceURL == nil || order.isEmpty)
            }
        }
        .navigationTitle("Reorder Pages")
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { urls in
                sourceURL = urls.first
                loadPages()
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Reorder Pages", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func loadPages() {
        guard let sourceURL, let pdf = PDFDocument(url: sourceURL) else { return }
        order = Array(0..<pdf.pageCount)
        thumbnails = order.compactMap { pdf.page(at: $0)?.thumbnail(of: CGSize(width: 92, height: 120), for: .cropBox) }
    }

    private func save() {
        guard let sourceURL else { return }
        Task {
            do {
                let data = try await PDFProcessingService.shared.reorderPages(from: sourceURL, order: order)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
