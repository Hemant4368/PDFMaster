import SwiftUI

struct OCRLanguage: Identifiable, Hashable {
    let name: String
    let code: String
    var id: String { code }

    static let all: [OCRLanguage] = [
        OCRLanguage(name: "Arabic",                   code: "ar-SA"),
        OCRLanguage(name: "Burmese",                  code: "my-MM"),
        OCRLanguage(name: "Catalan",                  code: "ca-ES"),
        OCRLanguage(name: "Chinese – Simplified",     code: "zh-Hans"),
        OCRLanguage(name: "Chinese – Traditional",    code: "zh-Hant"),
        OCRLanguage(name: "Czech",                    code: "cs-CZ"),
        OCRLanguage(name: "Danish",                   code: "da-DK"),
        OCRLanguage(name: "Dutch",                    code: "nl-NL"),
        OCRLanguage(name: "English",                  code: "en-US"),
        OCRLanguage(name: "Finnish",                  code: "fi-FI"),
        OCRLanguage(name: "French",                   code: "fr-FR"),
        OCRLanguage(name: "German",                   code: "de-DE"),
        OCRLanguage(name: "Greek",                    code: "el-GR"),
        OCRLanguage(name: "Hebrew",                   code: "he-IL"),
        OCRLanguage(name: "Hindi",                    code: "hi-IN"),
        OCRLanguage(name: "Hungarian",                code: "hu-HU"),
        OCRLanguage(name: "Indonesian",               code: "id-ID"),
        OCRLanguage(name: "Italian",                  code: "it-IT"),
        OCRLanguage(name: "Japanese",                 code: "ja-JP"),
        OCRLanguage(name: "Korean",                   code: "ko-KR"),
        OCRLanguage(name: "Norwegian",                code: "nb-NO"),
        OCRLanguage(name: "Polish",                   code: "pl-PL"),
        OCRLanguage(name: "Portuguese",               code: "pt-BR"),
        OCRLanguage(name: "Romanian",                 code: "ro-RO"),
        OCRLanguage(name: "Russian",                  code: "ru-RU"),
        OCRLanguage(name: "Slovak",                   code: "sk-SK"),
        OCRLanguage(name: "Spanish",                  code: "es-ES"),
        OCRLanguage(name: "Swedish",                  code: "sv-SE"),
        OCRLanguage(name: "Thai",                     code: "th-TH"),
        OCRLanguage(name: "Turkish",                  code: "tr-TR"),
        OCRLanguage(name: "Ukrainian",                code: "uk-UA"),
        OCRLanguage(name: "Vietnamese",               code: "vi-VT"),
    ]

    static var english: OCRLanguage { all.first { $0.code == "en-US" }! }
}

struct OCRLanguagePickerSheet: View {
    @Binding var selectedLanguages: Set<OCRLanguage>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [OCRLanguage] {
        searchText.isEmpty
            ? OCRLanguage.all
            : OCRLanguage.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { lang in
                Button {
                    if selectedLanguages.contains(lang) {
                        selectedLanguages.remove(lang)
                    } else {
                        selectedLanguages.insert(lang)
                    }
                } label: {
                    HStack {
                        Text(lang.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedLanguages.contains(lang) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.primary)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Recognition Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") { selectedLanguages.removeAll() }
                        .foregroundStyle(.red)
                        .disabled(selectedLanguages.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
