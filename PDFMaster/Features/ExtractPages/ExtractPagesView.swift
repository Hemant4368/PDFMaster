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

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("New PDF name", text: $title)
            }
            if pageCount > 0 {
                Section("Pages") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))]) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Button {
                                if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                            } label: {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 54, height: 54)
                                    .background(selected.contains(index) ? AppTheme.primary : Color(.secondarySystemBackground))
                                    .foregroundStyle(selected.contains(index) ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
            DocumentPickerView(allowsMultipleSelection: false) { urls in
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
                let data = delete
                    ? try await PDFProcessingService.shared.removePages(from: sourceURL, indexes: selected)
                    : try await PDFProcessingService.shared.extractPages(from: sourceURL, indexes: Array(selected))
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
