import PDFKit
import SwiftData
import SwiftUI

struct OCRToolView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var recognizedText = ""
    @State private var title = "OCR Text"
    @State private var language = "en-US"
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("Language", text: $language)
                PrimaryButton(title: "Recognize Text", systemImage: "text.viewfinder") { recognize() }
                    .disabled(sourceURL == nil)
            }
            Section("Editable OCR Text") {
                TextEditor(text: $recognizedText)
                    .frame(minHeight: 280)
            }
            Section {
                Button { UIPasteboard.general.string = recognizedText } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
                ShareLink(item: recognizedText) {
                    Label("Export Text", systemImage: "square.and.arrow.up")
                }
                Button("Save OCR History") {
                    modelContext.insert(OCRHistoryRecord(title: title, text: recognizedText, language: language))
                    try? modelContext.save()
                }
                .disabled(recognizedText.isEmpty)
            }
        }
        .navigationTitle("OCR Scanner")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) {
                sourceURL = $0.first
                title = sourceURL?.displayTitle ?? "OCR Text"
            }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Recognizing text") } }
        .alert("OCR", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func recognize() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                recognizedText = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: [language])
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
