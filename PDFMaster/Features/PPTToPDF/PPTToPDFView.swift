import SwiftUI

struct PPTToPDFView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var showPreview = false
    @AppStorage("pptToPDF.pageSize") private var pageSize: PDFPageSize = .a4
    @AppStorage("pptToPDF.orientation") private var orientation: PDFPageOrientation = .landscape

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PowerPoint (.ppt, .pptx)") {
                    showPicker = true
                }
            }

            if sourceURL != nil {
                Section("Output Options") {
                    Picker("Page Size", selection: $pageSize) {
                        ForEach(PDFPageSize.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    Picker("Orientation", selection: $orientation) {
                        ForEach(PDFPageOrientation.allCases) { o in Text(o.rawValue).tag(o) }
                    }
                }

                Section {
                    PrimaryButton(title: "Preview & Convert", systemImage: "play.rectangle") {
                        showPreview = true
                    }
                } footer: {
                    conversionInstructions
                }
            }
        }
        .navigationTitle("PowerPoint to PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(contentTypes: [.ppt, .pptx], allowsMultipleSelection: false) {
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
            Text("1. Tap \"Preview & Convert\" to open the presentation")
            Text("2. Tap the Share button (↑) in the top right")
            Text("3. Select Print \u{2192} pinch out on the preview")
            Text("4. In the Print dialog, set page size to \(pageSize.rawValue) and orientation to \(orientation.rawValue)")
            Text("5. Tap Share (↑) again \u{2192} Save to Files")
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
