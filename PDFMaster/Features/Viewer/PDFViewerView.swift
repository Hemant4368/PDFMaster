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
    @State private var showSignatureSheet = false
    @State private var signatureCanvas = PKCanvasView()
    @State private var showTextAlert = false
    @State private var textAnnotation = "Text"
    @State private var showReorderSheet = false
    @State private var reorderIndexes: [Int] = []
    @State private var showDeletePageConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let pdfDocument {
                VStack(spacing: 0) {
                    if showThumbnails { thumbnailStrip }
                    EditablePDFKitView(document: pdfDocument, currentPageIndex: $currentPageIndex, reloadToken: reloadToken)
                    viewerToolbar
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
//            ToolbarItem(placement: .topBarLeading) {
//                Button("Done") { dismiss() }
//            }
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
        .sheet(isPresented: $showSignatureSheet) { signatureSheet }
        .sheet(isPresented: $showReorderSheet) { reorderSheet }
        .alert("Add Text", isPresented: $showTextAlert) {
            TextField("Text", text: $textAnnotation)
            Button("Cancel", role: .cancel) {}
            Button("Add") { addTextAnnotation() }
        } message: {
            Text("Add a text annotation to the current page.")
        }
        .confirmationDialog("Delete this page?", isPresented: $showDeletePageConfirmation, titleVisibility: .visible) {
            Button("Delete Page", role: .destructive) {
                deleteCurrentPage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Page \(currentPageIndex + 1) will be removed from this PDF. Tap Save in files to keep the change.")
        }
        .alert("PDF Viewer", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if isSaving { LoadingOverlay(title: "Saving PDF") }
        }
    }

    private var viewerToolbar: some View {
        HStack(spacing: 0) {
            viewerAction("Add Page", "doc.badge.plus") { addPage() }
            viewerAction("Signature", "signature") { showSignatureSheet = true }
            viewerAction("Edit", "pencil.and.outline") { addHighlightAnnotation() }
            viewerAction("Text", "character.textbox") { showTextAlert = true }
            viewerAction("Reorder\npages", "arrow.up.arrow.down.square") { prepareReorder() }
            viewerAction("Delete\npage", "trash") { showDeletePageConfirmation = true }
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.bar)
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

    private func viewerAction(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(height: 24)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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

    private var signatureSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PencilCanvasView(canvasView: $signatureCanvas)
                    .frame(height: 240)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
                PrimaryButton(title: "Apply Signature", systemImage: "signature") {
                    applySignature()
                    showSignatureSheet = false
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { showSignatureSheet = false }
            }
        }
        .presentationDetents([.medium, .large])
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

    private func addHighlightAnnotation() {
        guard let page = currentPage() else { return }
        let bounds = page.bounds(for: .cropBox)
        let rect = CGRect(x: bounds.minX + 34, y: bounds.maxY - 120, width: bounds.width - 68, height: 26)
        let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
        annotation.color = AppTheme.primaryUIColor.withAlphaComponent(0.35)
        page.addAnnotation(annotation)
        markEdited()
    }

    private func addTextAnnotation() {
        guard let page = currentPage() else { return }
        let bounds = page.bounds(for: .cropBox)
        let rect = CGRect(x: bounds.midX - 120, y: bounds.midY - 24, width: 240, height: 48)
        let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        annotation.contents = textAnnotation
        annotation.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        annotation.fontColor = AppTheme.primaryUIColor
        annotation.color = .clear
        page.addAnnotation(annotation)
        markEdited()
    }

    private func applySignature() {
        guard let pdfDocument, let data = pdfDocument.dataRepresentation(), let signature = signatureImage() else { return }
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("viewer-sign-\(UUID().uuidString).pdf")
            try data.write(to: tempURL, options: .atomic)
            let page = pdfDocument.page(at: currentPageIndex)
            let bounds = page?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
            let rect = CGRect(x: bounds.midX - 110, y: bounds.maxY - 190, width: 220, height: 82)
            let signedData = try PDFProcessingServiceSync.sign(url: tempURL, signature: signature, pageIndex: currentPageIndex, rect: rect)
            self.pdfDocument = PDFDocument(data: signedData)
            try? FileManager.default.removeItem(at: tempURL)
            signatureCanvas.drawing = PKDrawing()
            markEdited()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signatureImage() -> UIImage? {
        let bounds = signatureCanvas.drawing.bounds.insetBy(dx: -18, dy: -18)
        guard !bounds.isEmpty else { return nil }
        return signatureCanvas.drawing.image(from: bounds, scale: UIScreen.main.scale)
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

    private func currentPage() -> PDFPage? {
        pdfDocument?.page(at: min(max(currentPageIndex, 0), max((pdfDocument?.pageCount ?? 1) - 1, 0)))
    }

    private func goToPage(_ index: Int) {
        currentPageIndex = index
    }
}

private enum PDFProcessingServiceSync {
    static func sign(url: URL, signature: UIImage, pageIndex: Int, rect: CGRect) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, .zero, nil)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            if index == pageIndex {
                signature.draw(in: rect)
            }
        }
        UIGraphicsEndPDFContext()
        return output as Data
    }
}
