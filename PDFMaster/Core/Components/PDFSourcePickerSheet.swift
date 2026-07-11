import SwiftData
import SwiftUI

struct PDFSourcePickerSheet: View {
    var allowsMultipleSelection: Bool = false
    let onSelect: ([URL]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentRecord.updatedAt, order: .reverse) private var allDocuments: [DocumentRecord]
    @State private var showFilePicker = false
    @State private var multiSelection = Set<UUID>()
    @State private var sortByName = false

    private var pdfDocuments: [DocumentRecord] {
        let pdfs = allDocuments.filter { $0.kind == .pdf }
        return sortByName
            ? pdfs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            : pdfs
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Browse Files App", systemImage: "folder")
                            .foregroundStyle(AppTheme.primary)
                    }
                } header: { Text("External") }

                if pdfDocuments.isEmpty {
                    Section {
                        Text("No PDFs saved in app yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: { Text("In App") }
                } else {
                    Section {
                        ForEach(pdfDocuments) { doc in
                            if allowsMultipleSelection {
                                multiRow(doc)
                            } else {
                                singleRow(doc)
                            }
                        }
                    } header: {
                        HStack {
                            Text("In App (\(pdfDocuments.count))")
                            Spacer()
                            Text(sortByName ? "A–Z" : "Recent first")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Choose PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if allowsMultipleSelection && !multiSelection.isEmpty {
                        Button("Add \(multiSelection.count)") { confirmMulti() }
                            .fontWeight(.semibold)
                    } else {
                        Button {
                            sortByName.toggle()
                        } label: {
                            Image(systemName: sortByName ? "textformat.abc" : "clock")
                                .symbolVariant(sortByName ? .none : .none)
                        }
                        .help(sortByName ? "Sorted by name — tap for recent" : "Sorted by recent — tap for name")
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView(allowsMultipleSelection: allowsMultipleSelection) { urls in
                    dismiss()
                    onSelect(urls)
                }
            }
        }
    }

    @ViewBuilder private func singleRow(_ doc: DocumentRecord) -> some View {
        Button {
            let url = FileStorageService.fileURL(for: doc.fileName)
            dismiss()
            onSelect([url])
        } label: {
            docRow(doc, selected: false)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func multiRow(_ doc: DocumentRecord) -> some View {
        Button {
            if multiSelection.contains(doc.id) {
                multiSelection.remove(doc.id)
            } else {
                multiSelection.insert(doc.id)
            }
        } label: {
            docRow(doc, selected: multiSelection.contains(doc.id))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func docRow(_ doc: DocumentRecord, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if doc.pageCount > 0 {
                        Text("\(doc.pageCount) pg")
                    }
                    Text(ByteCountFormatter.string(fromByteCount: doc.fileSize, countStyle: .file))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func confirmMulti() {
        let urls = pdfDocuments
            .filter { multiSelection.contains($0.id) }
            .map { FileStorageService.fileURL(for: $0.fileName) }
        dismiss()
        onSelect(urls)
    }
}
