import SwiftData
import SwiftUI

private enum HTMLInputMode: String, CaseIterable, Identifiable {
    case url  = "URL"
    case html = "HTML Code"
    var id: String { rawValue }
}

struct HTMLToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputMode: HTMLInputMode = .url
    @State private var urlText = "https://"
    @State private var htmlText = "<h1>Hello</h1><p>Your content here.</p>"
    @State private var title = "Web Page PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canConvert: Bool {
        switch inputMode {
        case .url:  URL(string: urlText) != nil && urlText != "https://"
        case .html: !htmlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        Form {
            Section("Source") {
                Picker("Input Type", selection: $inputMode) {
                    ForEach(HTMLInputMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if inputMode == .url {
                    TextField("https://example.com", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    TextEditor(text: $htmlText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                }
            }

            Section {
                TextField("Output name", text: $title)
            }

            Section {
                PrimaryButton(title: "Convert to PDF", systemImage: "globe") { convert() }
                    .disabled(!canConvert)
            }
        }
        .navigationTitle("HTML to PDF")
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to PDF") } }
        .alert("HTML to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func convert() {
        Task { @MainActor in
            isWorking = true
            defer { isWorking = false }
            do {
                let data: Data
                switch inputMode {
                case .url:
                    guard let pageURL = URL(string: urlText) else { throw URLError(.badURL) }
                    data = try await HTMLPDFRenderer.render(pageURL: pageURL)
                case .html:
                    data = try await HTMLPDFRenderer.render(htmlString: htmlText)
                }
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
