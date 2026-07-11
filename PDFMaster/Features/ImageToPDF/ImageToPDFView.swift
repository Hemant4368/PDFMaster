import PhotosUI
import SwiftData
import SwiftUI

struct ImageToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var title = "Images PDF"
    @State private var quality: PDFQuality = .balanced
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Label("Select Images", systemImage: "photo.on.rectangle.angled")
                }
                TextField("PDF name", text: $title)
                Picker("Compression", selection: $quality) {
                    ForEach(PDFQuality.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            if !images.isEmpty {
                Section("Reorder Images") {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        HStack {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 46, height: 60).clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Page \(index + 1)")
                            Spacer()
                        }
                    }
                    .onMove { source, destination in images.move(fromOffsets: source, toOffset: destination) }
                }
            }
            Section {
                PrimaryButton(title: "Convert to PDF", systemImage: "doc.richtext") { convert() }
                    .disabled(images.isEmpty || title.isEmpty)
            }
        }
        .navigationTitle("Image to PDF")
        .toolbar { EditButton() }
        .onChange(of: selectedItems) { _, newItems in loadImages(newItems) }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Building PDF") } }
        .alert("Image to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func loadImages(_ items: [PhotosPickerItem]) {
        Task {
            images.removeAll()
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
        }
    }

    private func convert() {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.makePDF(from: images, quality: quality)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
