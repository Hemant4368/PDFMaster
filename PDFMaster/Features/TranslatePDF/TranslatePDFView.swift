import PDFKit
import SwiftUI

struct TranslatePDFView: View {
    @EnvironmentObject private var shareInbox: ShareInbox
    @AppStorage("claude_api_key") private var apiKey = ""
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var extractedText = ""
    @State private var translatedText = ""
    @State private var targetLanguage = "French"
    @State private var showAPIKey = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let languages = ["French", "Spanish", "German", "Italian", "Portuguese",
                             "Chinese", "Japanese", "Korean", "Arabic", "Hindi", "Russian"]

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
            }

            Section("Translation") {
                Picker("Target Language", selection: $targetLanguage) {
                    ForEach(languages, id: \.self) { Text($0).tag($0) }
                }
                PrimaryButton(title: "Translate", systemImage: "character.book.closed") { translate() }
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
                        Image(systemName: showAPIKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                    }
                }
            } header: { Text("Claude API Key") } footer: {
                Text("Used to power AI translation. Get your key at console.anthropic.com.")
            }

            if !translatedText.isEmpty {
                Section("Translation") {
                    TextEditor(text: .constant(translatedText))
                        .frame(minHeight: 200)
                        .font(.callout)

                    ShareLink(item: translatedText) {
                        Label("Export Translation", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = translatedText
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .navigationTitle("Translate PDF")
        .task { if let url = shareInbox.consumeURL(for: .translatePDF) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in sourceURL = urls.first; translatedText = "" }
        }
        .overlay { if isWorking { LoadingOverlay(title: "Translating") } }
        .alert("Translate PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func translate() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                if extractedText.isEmpty || self.sourceURL?.lastPathComponent != sourceURL.lastPathComponent {
                    if let pdf = PDFDocument(url: sourceURL),
                       let raw = pdf.string,
                       !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        extractedText = String(raw.prefix(6000))
                    } else {
                        extractedText = String(
                            (try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: ["en-US"])).prefix(6000)
                        )
                    }
                }
                guard !extractedText.isEmpty else {
                    errorMessage = "No readable text found in this PDF."
                    return
                }
                translatedText = try await ClaudeService.shared.translate(
                    text: extractedText,
                    targetLanguage: targetLanguage,
                    apiKey: apiKey
                )
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
