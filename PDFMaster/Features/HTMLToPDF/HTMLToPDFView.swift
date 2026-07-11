import SwiftData
import SwiftUI

struct HTMLToPDFView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var urlText = "https://"
    @State private var committedURL = ""
    @State private var refreshTrigger = UUID()
    @State private var showOptions = false
    @State private var title = "Web Page PDF"

    // Options
    @State private var screenSize: HTMLScreenSize = .desktop
    @State private var pageSize: HTMLPageSize = .a4
    @State private var oneLongPage = false
    @State private var orientation: PDFPageOrientation = .portrait
    @State private var margin: PDFMarginSize = .none
    @State private var blockAds = false
    @State private var removePopups = false

    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var validURL: URL? {
        guard !urlText.isEmpty, urlText != "https://",
              let u = URL(string: urlText), u.scheme != nil else { return nil }
        return u
    }

    var body: some View {
        VStack(spacing: 0) {
            urlBar
            Divider()
            WebPreviewView(urlString: committedURL, screenSize: screenSize, refreshTrigger: refreshTrigger)
                .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("HTML to PDF")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showOptions) { optionsSheet }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to PDF") } }
        .alert("HTML to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: – URL bar

    private var urlBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("https://example.com", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .onSubmit { loadURL() }
                if !urlText.isEmpty && urlText != "https://" {
                    Button { urlText = "https://" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            Button { loadURL() } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(validURL != nil ? AppTheme.primary : .secondary)
            }
            .disabled(validURL == nil)

            Button {
                refreshTrigger = UUID()
                if committedURL.isEmpty, let u = validURL { committedURL = u.absoluteString }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(committedURL.isEmpty ? .secondary : AppTheme.primary)
            }
            .disabled(committedURL.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: – Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showOptions = true
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(AppTheme.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            Button { convert() } label: {
                Label("Convert to PDF", systemImage: "doc.richtext")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(validURL != nil ? AppTheme.primary : Color.secondary,
                                in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(validURL == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: – Options sheet

    private var optionsSheet: some View {
        NavigationStack {
            Form {
                Section("PDF Name") {
                    TextField("Output name", text: $title)
                }

                Section("Web Rendering") {
                    Picker("Screen Size", selection: $screenSize) {
                        ForEach(HTMLScreenSize.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Page Layout") {
                    Picker("Page Size", selection: $pageSize) {
                        ForEach(HTMLPageSize.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("One long page", isOn: $oneLongPage)
                    if !oneLongPage {
                        Picker("Orientation", selection: $orientation) {
                            ForEach(PDFPageOrientation.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                    Picker("Page Margin", selection: $margin) {
                        ForEach(PDFMarginSize.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("HTML Settings") {
                    Toggle("Try to block ads", isOn: $blockAds)
                    Toggle("Remove overlay popups", isOn: $removePopups)
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showOptions = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: – Actions

    private func loadURL() {
        guard let u = validURL else { return }
        committedURL = u.absoluteString
        refreshTrigger = UUID()
    }

    private func convert() {
        guard let u = validURL else { return }
        Task { @MainActor in
            isWorking = true
            defer { isWorking = false }
            do {
                let opts = HTMLPDFRenderer.RenderOptions(
                    viewportWidth: screenSize.width,
                    pageSize: pageSize,
                    oneLongPage: oneLongPage,
                    orientation: oneLongPage ? .portrait : orientation,
                    margin: margin,
                    blockAds: blockAds,
                    removePopups: removePopups
                )
                let data = try await HTMLPDFRenderer.render(pageURL: u, options: opts)
                savedDocument = try await SaveDocumentHelper.savePDF(
                    data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
