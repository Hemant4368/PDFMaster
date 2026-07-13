import SwiftUI

struct ExcelToPDFView: View {
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var showPreview = false
    @AppStorage("excelToPDF.pageSize") private var pageSize: PDFPageSize = .a4
    @AppStorage("excelToPDF.orientation") private var orientation: PDFPageOrientation = .landscape
    @AppStorage("excelToPDF.fitToWidth") private var fitToWidth = true

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose Excel Spreadsheet (.xls, .xlsx)") {
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
                    Toggle("Fit all columns to one page", isOn: $fitToWidth)
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
            Text("3. Select Print \u{2192} pinch out on the preview")
            Text("4. In Print dialog: orientation = \(orientation.rawValue)\(fitToWidth ? ", enable Fit to Width" : "")")
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
