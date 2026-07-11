import SwiftUI

struct WordToPDFView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var showPreview = false

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose Word Document (.docx)") {
                    showPicker = true
                }
            }

            if sourceURL != nil {
                Section {
                    PrimaryButton(title: "Preview & Convert", systemImage: "doc.richtext") {
                        showPreview = true
                    }
                } footer: {
                    conversionInstructions
                }
            }
        }
        .navigationTitle("Word to PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(contentTypes: [.docx], allowsMultipleSelection: false) {
                sourceURL = $0.first
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let url = sourceURL {
                OfficePreviewSheet(url: url, dismiss: { showPreview = false })
            }
        }
    }

    private var conversionInstructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to convert to PDF:").font(.caption).bold()
            Text("1. Tap \"Preview & Convert\" to open the document")
            Text("2. Tap the Share button (↑) in the top right")
            Text("3. Select Print → pinch out on the preview")
            Text("4. Tap Share (↑) again → Save to Files")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct OfficePreviewSheet: View {
    let url: URL
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            QLPreviewControllerView(url: url)
                .ignoresSafeArea()
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
