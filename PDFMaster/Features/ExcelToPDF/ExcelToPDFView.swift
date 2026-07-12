import SwiftUI

struct ExcelToPDFView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var showPreview = false
    @State private var options = OfficeConversionOptions()

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose Excel Spreadsheet (.xls, .xlsx)") {
                    showPicker = true
                }
            }

            if sourceURL != nil {
                Section("Options") {
                    TextField("Output Name", text: $options.outputName)
                    Picker("Orientation", selection: $options.orientation) {
                        ForEach(PDFPageOrientation.allCases) { orient in
                            Text(orient.rawValue).tag(orient)
                        }
                    }
                    Picker("Quality", selection: $options.quality) {
                        ForEach(PDFQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    Picker("Margin", selection: $options.margin) {
                        ForEach(PDFMarginSize.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                }

                Section {
                    PrimaryButton(title: "Preview & Convert", systemImage: "tablecells") {
                        showPreview = true
                    }
                } footer: {
                    conversionInstructions
                }
            }
        }
        .navigationTitle("Excel to PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(contentTypes: [.xls, .xlsx], allowsMultipleSelection: false) {
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
            Text("1. Tap \"Preview & Convert\" to open the spreadsheet")
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
