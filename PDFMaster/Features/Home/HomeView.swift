import PDFKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var showScanner: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentRecord.updatedAt, order: .reverse) private var documents: [DocumentRecord]
    @StateObject private var viewModel = HomeViewModel()
    @State private var showImporter = false
    @State private var selectedTool: PDFTool?
    @State private var renamingDocument: DocumentRecord?
    @State private var renameTitle = ""
    @State private var isEditingFiles = false
    @State private var selectedDocumentIDs = Set<UUID>()

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    PrimaryButton(title: "Import", systemImage: "square.and.arrow.down") {
                        showImporter = true
                    }
                    recentFiles
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !documents.isEmpty {
                        Button(isEditingFiles ? "Cancel" : "Edit") {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isEditingFiles.toggle()
                                selectedDocumentIDs.removeAll()
                            }
                        }
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .refreshable { viewModel.loadThumbnails(for: documents) }
            .navigationDestination(item: $viewModel.pickedDocument) { document in
                PDFViewerView(document: document)
            }
            .navigationDestination(item: $selectedTool) { tool in
                ToolRouterView(tool: tool)
            }
            .sheet(isPresented: $showImporter) {
                DocumentPickerView(allowsMultipleSelection: true) { urls in
                    viewModel.importFiles(urls, modelContext: modelContext)
                }
            }
            .sheet(item: $viewModel.sharePayload) { payload in
                ShareSheet(items: payload.urls)
            }
            .alert("Rename File", isPresented: renameAlertBinding) {
                TextField("File name", text: $renameTitle)
                Button("Cancel", role: .cancel) {
                    renamingDocument = nil
                    renameTitle = ""
                }
                Button("Save") {
                    if let renamingDocument {
                        viewModel.rename(renamingDocument, to: renameTitle, modelContext: modelContext)
                    }
                    renamingDocument = nil
                    renameTitle = ""
                }
                .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a new name for this PDF.")
            }
            .overlay {
                if viewModel.isImporting { LoadingOverlay(title: "Importing files") }
            }
            .overlay(alignment: .bottom) {
                if isEditingFiles {
                    selectionActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert("PDF Master AI", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear { viewModel.loadThumbnails(for: documents) }
            .onChange(of: documents) { _, newValue in viewModel.loadThumbnails(for: newValue) }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                
                Text("Scan Your Documents")
                    .font(
                        .system(
                            size: 26,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)
                
                Text("Scan, edit, convert, sign & secure PDFs instantly")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { showScanner = true } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.redGradient)
                    .clipShape(Circle())
            }
        }
    }

    private var recentFiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            let filtered = viewModel.filtered(documents)
            HStack {
                Text("All Files")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                if isEditingFiles && !filtered.isEmpty {
                    Button(selectedDocumentIDs.count == filtered.count ? "Deselect All" : "Select All") {
                        withAnimation {
                            if selectedDocumentIDs.count == filtered.count {
                                selectedDocumentIDs.removeAll()
                            } else {
                                selectedDocumentIDs = Set(filtered.map(\.id))
                            }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }
            }
            if filtered.isEmpty {
                EmptyStateView(title: "No files yet", message: "Import a PDF or tap the scanner to create your first document.", systemImage: "doc.badge.plus")
                    .premiumCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(filtered.prefix(8)) { document in
                        DocumentRow(
                            document: document,
                            thumbnail: viewModel.thumbnails[document.id],
                            isSelectionMode: isEditingFiles,
                            isSelected: selectedDocumentIDs.contains(document.id),
                            action: { viewModel.pickedDocument = document },
                            toggleSelection: { toggleSelection(for: document) },
                            share: { viewModel.share(document) },
                            rename: { beginRename(document) },
                            duplicate: { viewModel.duplicate(document, modelContext: modelContext) },
                            delete: { viewModel.delete(document, modelContext: modelContext) }
                        )
                        .contextMenu {
                            if isEditingFiles {
                                Button(selectedDocumentIDs.contains(document.id) ? "Deselect" : "Select") {
                                    toggleSelection(for: document)
                                }
                            } else {
                                Button("Rename") { beginRename(document) }
                                Button("Duplicate") { viewModel.duplicate(document, modelContext: modelContext) }
                                Button("Share") { viewModel.share(document) }
                                Button("Delete", role: .destructive) { viewModel.delete(document, modelContext: modelContext) }
                            }
                        }
                        if document.id != filtered.prefix(8).last?.id { Divider() }
                    }
                }
                .premiumCard(padding: 12)
            }
        }
    }

    private var selectionActionBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedDocumentIDs.count) selected")
                    .font(.headline)
                Text("Choose files to share or delete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                shareSelectedDocuments()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedDocumentIDs.isEmpty)
            .foregroundStyle(selectedDocumentIDs.isEmpty ? .secondary : AppTheme.primary)

            Button(role: .destructive) {
                deleteSelectedDocuments()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedDocumentIDs.isEmpty)
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 88)
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingDocument != nil },
            set: { isPresented in
                if !isPresented {
                    renamingDocument = nil
                    renameTitle = ""
                }
            }
        )
    }

    private func beginRename(_ document: DocumentRecord) {
        renamingDocument = document
        renameTitle = document.title
    }

    private func toggleSelection(for document: DocumentRecord) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
            if selectedDocumentIDs.contains(document.id) {
                selectedDocumentIDs.remove(document.id)
            } else {
                selectedDocumentIDs.insert(document.id)
            }
        }
    }

    private func selectedDocuments() -> [DocumentRecord] {
        documents.filter { selectedDocumentIDs.contains($0.id) }
    }

    private func shareSelectedDocuments() {
        let selected = selectedDocuments()
        guard !selected.isEmpty else { return }
        viewModel.share(selected)
    }

    private func deleteSelectedDocuments() {
        let selected = selectedDocuments()
        guard !selected.isEmpty else { return }
        viewModel.delete(selected, modelContext: modelContext)
        withAnimation {
            selectedDocumentIDs.removeAll()
            isEditingFiles = false
        }
    }

}

#Preview {
    HomeView(showScanner: .constant(false))
}
