import PDFKit
import PencilKit
import SwiftData
import SwiftUI

struct PDFViewerView: View {
    let document: DocumentRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var url: URL?
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var reloadToken = UUID()
    @State private var shareURL: URL?
    @State private var thumbnails: [UIImage] = []
    @State private var showThumbnails = false
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @State private var showReorderSheet = false
    @State private var reorderIndexes: [Int] = []
    @State private var showDeletePageConfirmation = false
    @State private var errorMessage: String?
    @StateObject private var editorVM = PDFEditorViewModel()

    var body: some View {
        Group {
            if let pdfDocument {
                VStack(spacing: 0) {
                    if showThumbnails { thumbnailStrip }
                    InteractivePDFKitView(
                        document: pdfDocument,
                        currentPageIndex: $currentPageIndex,
                        reloadToken: reloadToken,
                        editorViewModel: editorVM
                    )

                    PDFEditorToolbar(
                        viewModel: editorVM,
                        documentPageCount: pdfDocument.pageCount,
                        currentPageIndex: currentPageIndex,
                        onSave: saveEditedPDF,
                        onPrint: { if let url { PrintController.printPDF(url: url) } },
                        onAddPage: addPage,
                        onDeletePage: { showDeletePageConfirmation = true },
                        onReorder: prepareReorder,
                        onMarkupApply: { editorVM.applyMarkupFromSelection(); markEdited() },
                        onApplyRedactions: { editorVM.applyRedactions(to: pdfDocument); markEdited() }
                    )

                    if hasUnsavedChanges {
                        saveButton
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.86), value: hasUnsavedChanges)
            } else {
                ProgressView()
                    .task { await loadDocument() }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { editorVM.showSidebar = true } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showThumbnails.toggle(); loadThumbnails() } label: {
                    Image(systemName: "square.grid.2x2")
                }
                Button { if let url { PrintController.printPDF(url: url) } } label: {
                    Image(systemName: "printer")
                }
                Button { shareURL = url } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $shareURL) { ShareSheet(items: [$0]) }
        .sheet(isPresented: $editorVM.showSignatureSheet) {
            PDFSignatureSheet(viewModel: editorVM)
        }
        .sheet(isPresented: $showReorderSheet) { reorderSheet }
        .sheet(isPresented: $editorVM.showInspector) {
            PDFAnnotationInspector(viewModel: editorVM)
        }
        .sheet(isPresented: $editorVM.showStampPicker) {
            PDFStampPicker(viewModel: editorVM)
        }
        .sheet(isPresented: $editorVM.showSearchPanel) {
            PDFSearchPanel(viewModel: editorVM)
        }
        .sheet(isPresented: $editorVM.showSidebar) {
            AnnotationSidebar(viewModel: editorVM)
        }
        .sheet(isPresented: $editorVM.showNoteEditor) {
            if let annotation = editorVM.noteToEdit {
                AnnotationNoteEditor(viewModel: editorVM, annotation: annotation)
            }
        }
        .alert("Add Text", isPresented: $editorVM.showTextInput) {
            TextField("Text", text: $editorVM.textInputValue)
            Button("Cancel", role: .cancel) { editorVM.pendingTapPoint = nil }
            Button("Add") { editorVM.confirmTextAnnotation(); markEdited() }
        } message: {
            Text("Tap a location on the PDF to place this text.")
        }
        .confirmationDialog("Delete this page?", isPresented: $showDeletePageConfirmation, titleVisibility: .visible) {
            Button("Delete Page", role: .destructive) { deleteCurrentPage() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Page \(currentPageIndex + 1) will be removed from this PDF.")
        }
        .alert("PDF Viewer", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if isSaving { LoadingOverlay(title: "Saving PDF") }
        }
        .onChange(of: editorVM.searchText) {
            guard editorVM.showSearchPanel, let pdfDocument else { return }
            editorVM.performSearch(in: pdfDocument)
        }
        .onReceive(editorVM.storage.$editCount.dropFirst()) { _ in
            markEdited()
        }
    }

    private var saveButton: some View {
        Button { saveEditedPDF() } label: {
            Text("Save in files")
                .redButtonStyle()
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
        }
        .background(Color(.systemBackground))
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, image in
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                if index == currentPageIndex {
                                    RoundedRectangle(cornerRadius: 6).stroke(AppTheme.primary, lineWidth: 2)
                                }
                            }
                        Text("\(index + 1)")
                            .font(.caption2)
                    }
                    .onTapGesture { goToPage(index) }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    private var reorderSheet: some View {
        NavigationStack {
            List {
                ForEach(reorderIndexes, id: \.self) { index in
                    HStack {
                        if let page = pdfDocument?.page(at: index) {
                            Image(uiImage: page.thumbnail(of: CGSize(width: 70, height: 92), for: .cropBox))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 42, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text("Page \(index + 1)")
                    }
                }
                .onMove { reorderIndexes.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("Reorder Pages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showReorderSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { applyReorder() }
                }
            }
        }
    }

    private func loadDocument() async {
        let fileURL = await FileStorageService.shared.url(for: document.fileName)
        url = fileURL
        pdfDocument = PDFDocument(url: fileURL)
        loadThumbnails()
    }

    private func markEdited() {
        hasUnsavedChanges = true
        thumbnails.removeAll()
        loadThumbnails()
        reloadToken = UUID()
    }

    private func addPage() {
        guard let pdfDocument else { return }
        let size = pdfDocument.page(at: currentPageIndex)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let page = PDFPage(image: image) else { return }
        pdfDocument.insert(page, at: min(currentPageIndex + 1, pdfDocument.pageCount))
        currentPageIndex = min(currentPageIndex + 1, pdfDocument.pageCount - 1)
        markEdited()
    }

    private func prepareReorder() {
        guard let pdfDocument else { return }
        reorderIndexes = Array(0..<pdfDocument.pageCount)
        showReorderSheet = true
    }

    private func applyReorder() {
        guard let pdfDocument else { return }
        let output = PDFDocument()
        for (newIndex, oldIndex) in reorderIndexes.enumerated() {
            if let page = pdfDocument.page(at: oldIndex) {
                output.insert(page, at: newIndex)
            }
        }
        self.pdfDocument = output
        currentPageIndex = 0
        showReorderSheet = false
        markEdited()
    }

    private func deleteCurrentPage() {
        guard let pdfDocument else { return }
        guard pdfDocument.pageCount > 1 else {
            errorMessage = "A PDF must contain at least one page."
            return
        }
        let deletedIndex = min(max(currentPageIndex, 0), pdfDocument.pageCount - 1)
        pdfDocument.removePage(at: deletedIndex)
        currentPageIndex = min(deletedIndex, pdfDocument.pageCount - 1)
        markEdited()
    }

    private func saveEditedPDF() {
        guard let pdfDocument, let url, let data = pdfDocument.dataRepresentation() else { return }
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try data.write(to: url, options: .atomic)
                document.pageCount = pdfDocument.pageCount
                document.fileSize = await FileStorageService.shared.fileSize(at: url)
                document.updatedAt = .now
                try modelContext.save()
                hasUnsavedChanges = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadThumbnails() {
        guard thumbnails.isEmpty, let pdfDocument else { return }
        thumbnails = (0..<pdfDocument.pageCount).compactMap {
            pdfDocument.page(at: $0)?.thumbnail(of: CGSize(width: 90, height: 120), for: .cropBox)
        }
    }

    private func goToPage(_ index: Int) {
        currentPageIndex = index
    }
}
