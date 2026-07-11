import PDFKit
import SwiftData
import SwiftUI

struct OCRToolView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var showLanguagePicker = false
    @State private var recognizedText = ""
    @State private var title = "OCR Text"
    @State private var selectedLanguages: Set<OCRLanguage> = [.english]
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var sortedLanguages: [OCRLanguage] {
        selectedLanguages.sorted { $0.name < $1.name }
    }

    private var languageSummary: String {
        selectedLanguages.isEmpty ? "None selected" : sortedLanguages.map(\.name).joined(separator: ", ")
    }

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
            }

            Section {
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack {
                        Text("Languages")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(languageSummary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !selectedLanguages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedLanguages) { lang in
                                HStack(spacing: 4) {
                                    Text(lang.name)
                                        .font(.caption.weight(.medium))
                                    Button {
                                        selectedLanguages.remove(lang)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2.weight(.bold))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppTheme.primary.opacity(0.12))
                                .foregroundStyle(AppTheme.primary)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: { Text("Recognition Language") } footer: {
                Text("Select one or more languages that appear in your PDF for best accuracy.")
            }

            Section {
                PrimaryButton(title: "Recognize Text", systemImage: "text.viewfinder") { recognize() }
                    .disabled(sourceURL == nil || selectedLanguages.isEmpty)
            }

            Section("Recognized Text") {
                if recognizedText.isEmpty {
                    Text("Recognized text will appear here after running OCR.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    TextEditor(text: $recognizedText)
                        .frame(minHeight: 280)
                }
            }

            if !recognizedText.isEmpty {
                Section {
                    Button {
                        UIPasteboard.general.string = recognizedText
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: recognizedText) {
                        Label("Export Text", systemImage: "square.and.arrow.up")
                    }
                    Button("Save to OCR History") {
                        let langs = sortedLanguages.map(\.name).joined(separator: ", ")
                        modelContext.insert(OCRHistoryRecord(title: title, text: recognizedText, language: langs))
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("OCR Scanner")
        .task { if let url = shareInbox.consumeURL(for: .ocr) { sourceURL = url } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                title = sourceURL?.displayTitle ?? "OCR Text"
                recognizedText = ""
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            OCRLanguagePickerSheet(selectedLanguages: $selectedLanguages)
        }
        .overlay { if isWorking { LoadingOverlay(title: "Recognizing text") } }
        .alert("OCR", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func recognize() {
        guard let sourceURL, !selectedLanguages.isEmpty else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let codes = sortedLanguages.map(\.code)
                let raw = try await OCRService.shared.recognizeText(inPDF: sourceURL, languages: codes)
                recognizedText = cleanText(raw)
                if recognizedText.isEmpty {
                    errorMessage = "No text was recognized. Try a different language or a higher-quality PDF."
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func cleanText(_ raw: String) -> String {
        var result: [String] = []
        var prevEmpty = false
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !prevEmpty && !result.isEmpty { result.append("") }
                prevEmpty = true
            } else {
                result.append(trimmed)
                prevEmpty = false
            }
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n")
    }
}
