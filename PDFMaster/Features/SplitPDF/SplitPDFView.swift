import PDFKit
import SwiftData
import SwiftUI

struct SplitPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var rangesText = ""
    @State private var pageCount = 0
    @State private var splitURLs: [URL] = []
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if pageCount > 0 {
                    LabeledContent("Pages", value: "\(pageCount)")
                }
                TextField("Ranges, e.g. 1-3, 4-6", text: $rangesText)
                    .keyboardType(.numbersAndPunctuation)
            } header: { Text("Input") } footer: {
                Text("Enter page ranges separated by commas. Pages are numbered from 1.")
            }

            Section {
                PrimaryButton(title: "Split PDF", systemImage: "scissors") { split() }
                    .disabled(sourceURL == nil || rangesText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !splitURLs.isEmpty {
                Section("Split Parts — Share or Save") {
                    ForEach(Array(splitURLs.enumerated()), id: \.offset) { index, url in
                        ShareLink(item: url) {
                            Label("Part \(index + 1)", systemImage: "doc.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle("Split PDF")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { urls in
                sourceURL = urls.first
                if let u = urls.first, let pdf = PDFDocument(url: u) {
                    pageCount = pdf.pageCount
                    let mid = max(1, pageCount / 2)
                    rangesText = pageCount > 1 ? "1-\(mid), \(mid + 1)-\(pageCount)" : "1-\(pageCount)"
                }
                splitURLs = []
            }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Splitting PDF") } }
        .alert("Split PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func split() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let parts = try await PDFProcessingService.shared.split(url: sourceURL, rangesString: rangesText)
                let base = sourceURL.deletingPathExtension().lastPathComponent
                splitURLs = try parts.enumerated().map { index, data in
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(base)-part-\(index + 1).pdf")
                    try data.write(to: url, options: .atomic)
                    return url
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
