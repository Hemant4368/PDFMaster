import PDFKit
import SwiftUI

struct AISummarizerView: View {
    @EnvironmentObject private var shareInbox: ShareInbox
    @AppStorage("claude_api_key") private var apiKey = ""
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var summary = ""
    @State private var showAPIKey = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                PrimaryButton(title: "Summarize", systemImage: "sparkles.rectangle.stack") { summarize() }
                    .disabled(sourceURL == nil || apiKey.isEmpty)
            }

            Section {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Claude API Key", text: $apiKey)
                    }
                    Button { showAPIKey.toggle() } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: { Text("Claude API Key") } footer: {
                Text("Get your key at console.anthropic.com. Stored locally on this device only.")
            }

            if !summary.isEmpty {
                Section("Summary") {
                    Text(summary)
                        .font(.callout)
                        .textSelection(.enabled)

                    ShareLink(item: summary) {
                        Label("Export Summary", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = summary
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .navigationTitle("AI Summarizer")
        .task { if let url = shareInbox.consumeURL(for: .aiSummarizer) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; summary = "" }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Summarizing") } }
        .alert("AI Summarizer", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func summarize() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let text: String
                if let pdf = PDFDocument(url: sourceURL),
                   let raw = pdf.string,
                   !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = String(raw.prefix(8000))
                } else {
                    let ocr = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: ["en-US"])
                    text = String(ocr.prefix(8000))
                }
                guard !text.isEmpty else {
                    errorMessage = "No readable text found in this PDF."
                    return
                }
                summary = try await ClaudeService.shared.summarize(text: text, apiKey: apiKey)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
