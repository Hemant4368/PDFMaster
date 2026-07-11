import PDFKit
import SwiftUI

struct PDFSearchPanel: View {
    @ObservedObject var viewModel: PDFEditorViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search text", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit { search() }
                }
                .padding(.horizontal)

                if !viewModel.searchResults.isEmpty {
                    HStack(spacing: 12) {
                        Button { viewModel.previousResult(); navigateToResult() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.searchResults.isEmpty)

                        Text("\(viewModel.searchResultIndex + 1) of \(viewModel.searchResults.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button { viewModel.nextResult(); navigateToResult() } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.searchResults.isEmpty)

                        Spacer()

                        Button("Done") { viewModel.editorMode = .view; viewModel.showSearchPanel = false }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .padding(.horizontal)

                    List {
                        ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { index, selection in
                            Button {
                                viewModel.searchResultIndex = index
                                navigateToResult()
                            } label: {
                                HStack {
                                    Text(selection.pages.first.map { "Page \($0.label ?? "?")" } ?? "Page ?")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(selection.string ?? "")
                                        .lineLimit(1)
                                        .font(.subheadline)
                                    Spacer()
                                    if index == viewModel.searchResultIndex {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                } else if !viewModel.searchText.isEmpty {
                    Text("No results found")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func search() {
        guard let pdfView = viewModel.pdfView, let document = pdfView.document else { return }
        viewModel.performSearch(in: document)
        navigateToResult()
    }

    private func navigateToResult() {
        guard let selection = viewModel.currentSearchResult, let pdfView = viewModel.pdfView else { return }
        pdfView.go(to: selection)
        viewModel.editorMode = .view
    }
}
