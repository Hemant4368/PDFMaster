import PDFKit
import SwiftData
import SwiftUI

struct ExtractPagesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var pageCount = 0
    @State private var selected = Set<Int>()
    @State private var showPicker = false
    @State private var title = "Extracted Pages"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?
    @AppStorage("extract.separateFiles") private var separateFiles = false

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("New PDF name", text: $title)
            }
            if pageCount > 0 {
                Section("Pages") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 14) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            if let sourceURL {
                                PageThumbnailChip(
                                    pdfURL: sourceURL,
                                    index: index,
                                    isSelected: selected.contains(index)
                                ) {
                                    if selected.contains(index) { selected.remove(index) }
                                    else { selected.insert(index) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Output") {
                Toggle("Export each page as a separate PDF", isOn: $separateFiles)
            }

            Section {
                PrimaryButton(title: "Export Selected Pages", systemImage: "doc.on.doc") { export(delete: false) }
                    .disabled(selected.isEmpty)
                Button(role: .destructive) { export(delete: true) } label: {
                    Label("Delete Selected Pages", systemImage: "trash")
                }
                .disabled(selected.isEmpty || selected.count == pageCount)
            }
        }
        .navigationTitle("Extract Pages")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let sourceURL, let pdf = PDFDocument(url: sourceURL) { pageCount = pdf.pageCount }
                selected.removeAll()
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Extract Pages", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func export(delete: Bool) {
        guard let sourceURL else { return }
        Task {
            do {
                if delete {
                    let data = try await PDFProcessingService.shared.removePages(from: sourceURL, indexes: selected)
                    savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
                } else if separateFiles {
                    let pages = try await PDFProcessingService.shared.splitSelectedPages(url: sourceURL, pageIndexes: Array(selected).sorted())
                    let base = sourceURL.deletingPathExtension().lastPathComponent
                    for (i, data) in pages.enumerated() {
                        _ = try await SaveDocumentHelper.savePDF(data: data, title: "\(base) – Page \(selected.sorted()[i] + 1)", modelContext: modelContext)
                    }
                } else {
                    let data = try await PDFProcessingService.shared.extractPages(from: sourceURL, indexes: Array(selected))
                    savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
