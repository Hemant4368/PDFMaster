import SwiftData
import SwiftUI

struct MergePDFView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var urls: [URL] = []
    @State private var showPicker = false
    @State private var title = "Merged PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button("Select PDFs") { showPicker = true }
                TextField("Merged PDF name", text: $title)
            }
            Section {
                if urls.isEmpty {
                    Text("Choose two or more PDFs.")
                        .foregroundStyle(.secondary)
                }
                ForEach(urls) { url in
                    Label(url.lastPathComponent, systemImage: "doc.richtext")
                }
                .onMove { urls.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { urls.remove(atOffsets: $0) }
            } header: {
                HStack {
                    Text("Files (\(urls.count))")
                    Spacer()
                    if urls.count > 1 {
                        Button {
                            withAnimation {
                                urls.sort {
                                    $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
                                }
                            }
                        } label: {
                            Label("Sort A–Z", systemImage: "textformat.abc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            Section {
                PrimaryButton(title: "Merge PDFs", systemImage: "square.stack.3d.down.forward") { merge() }
                    .disabled(urls.count < 2)
            }
        }
        .navigationTitle("Merge PDFs")
        .task { if let url = shareInbox.consumeURL(for: .merge) { urls = [url] } }
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet(allowsMultipleSelection: true) { picked in urls = picked }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Merging PDFs") } }
        .alert("Merge PDFs", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func merge() {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.merge(urls)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
