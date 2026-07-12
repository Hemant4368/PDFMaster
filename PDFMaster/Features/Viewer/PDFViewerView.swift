import PDFKit
import SwiftUI

struct PDFViewerView: View {
    let document: DocumentRecord

    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var reloadToken = UUID()
    @State private var shareURL: URL?
    @State private var thumbnails: [UIImage] = []
    @State private var showThumbnails = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if let pdfDocument {
                pdfContainer(pdfDocument)
            } else if let loadError {
                ContentUnavailableView(
                    "Failed to Load PDF",
                    systemImage: "doc.richtext",
                    description: Text(loadError)
                )
            } else {
                loadingView
                    .task { await loadDocument() }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let pdfDocument {
                        Text("Page \(currentPageIndex + 1) of \(pdfDocument.pageCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showThumbnails.toggle()
                        if showThumbnails { loadThumbnails() }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .fontWeight(showThumbnails ? .bold : .regular)
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
        .preferredColorScheme(.light)
    }

    // MARK: - PDF Container

    private func pdfContainer(_ pdf: PDFDocument) -> some View {
        VStack(spacing: 0) {
            if showThumbnails {
                thumbnailStrip
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            EditablePDFKitView(
                document: pdf,
                currentPageIndex: $currentPageIndex,
                reloadToken: reloadToken
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showThumbnails)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Opening PDF...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Thumbnails

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, image in
                    VStack(spacing: 4) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                if index == currentPageIndex {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.primary, lineWidth: 2.5)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                }
                            }
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(index == currentPageIndex ? AppTheme.primary : .secondary)
                    }
                    .scaleEffect(index == currentPageIndex ? 1.05 : 1)
                    .onTapGesture { currentPageIndex = index }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func loadDocument() async {
        let fileURL = await FileStorageService.shared.url(for: document.fileName)
        url = fileURL
        pdfDocument = PDFDocument(url: fileURL)
        if pdfDocument == nil {
            loadError = "The document could not be opened. It may be corrupted or in an unsupported format."
        }
        loadThumbnails()
    }

    private func loadThumbnails() {
        guard thumbnails.isEmpty, let pdfDocument else { return }
        let totalPages = pdfDocument.pageCount
        thumbnails = []
        Task.detached(priority: .utility) { [weak pdfDocument] in
            guard let doc = pdfDocument else { return }
            for start in stride(from: 0, to: totalPages, by: 20) {
                let end = min(start + 20, totalPages)
                var batch: [(Int, UIImage)] = []
                for i in start..<end {
                    if let page = doc.page(at: i) {
                        batch.append((i, page.thumbnail(of: CGSize(width: 48, height: 64), for: .cropBox)))
                    }
                }
                await MainActor.run { [batch] in
                    for (idx, img) in batch {
                        if self.thumbnails.indices.contains(idx) {
                            self.thumbnails[idx] = img
                        } else {
                            self.thumbnails.append(img)
                        }
                    }
                }
            }
        }
    }
}
