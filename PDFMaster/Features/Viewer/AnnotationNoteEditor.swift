import PDFKit
import SwiftUI

struct AnnotationNoteEditor: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    let annotation: PDFAnnotation
    @State private var noteText: String
    @State private var replies: [AnnotationComment]
    @State private var newReplyText = ""
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PDFEditorViewModel, annotation: PDFAnnotation) {
        self.viewModel = viewModel
        self.annotation = annotation
        let raw = annotation.contents ?? ""
        let parts = raw.components(separatedBy: "\n---REPLIES---\n")
        _noteText = State(initialValue: parts.first ?? raw)
        if parts.count > 1 {
            let replyLines = parts[1].components(separatedBy: "\n")
            _replies = State(initialValue: replyLines.compactMap { line in
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return AnnotationComment(
                    id: AnnotationID(),
                    author: AnnotationAuthor(name: UIDevice.current.name),
                    text: line,
                    date: Date(),
                    replies: []
                )
            })
        } else {
            _replies = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                    HStack {
                        Text("Author:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(annotation.userName ?? UIDevice.current.name)
                            .font(.caption)
                    }
                    if let date = annotation.modificationDate {
                        HStack {
                            Text("Modified:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(date, style: .date)
                                .font(.caption)
                            Text(date, style: .time)
                                .font(.caption)
                        }
                    }
                }

                if !replies.isEmpty {
                    Section("Replies (\(replies.count))") {
                        ForEach(replies) { reply in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reply.text)
                                    .font(.subheadline)
                                HStack {
                                    Text(reply.author.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(reply.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    replies.removeAll { $0.id == reply.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Add Reply") {
                    HStack {
                        TextField("Write a reply...", text: $newReplyText)
                        Button("Send") {
                            guard !newReplyText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let reply = AnnotationComment(
                                id: AnnotationID(),
                                author: AnnotationAuthor(name: UIDevice.current.name),
                                text: newReplyText.trimmingCharacters(in: .whitespaces),
                                date: Date(),
                                replies: []
                            )
                            replies.append(reply)
                            newReplyText = ""
                        }
                        .disabled(newReplyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if let page = annotation.page {
                            viewModel.removeAnnotation(annotation, from: page)
                        }
                        dismiss()
                    } label: {
                        Label("Delete Note", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Sticky Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    saveNote()
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
    }

    private func saveNote() {
        let replyText = replies.isEmpty ? "" : "\n---REPLIES---\n" + replies.map(\.text).joined(separator: "\n")
        annotation.contents = noteText + replyText
        annotation.modificationDate = Date()
        viewModel.storage.editCount += 1
    }
}
