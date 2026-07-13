import PDFKit
import SwiftData
import SwiftUI

private enum SplitTopMode: String, CaseIterable, Identifiable {
    case range = "Range", page = "Page", size = "Size"
    var id: String { rawValue }
}

private enum SplitRangeSubMode: String, CaseIterable, Identifiable {
    case custom = "Custom", fixed = "Fixed"
    var id: String { rawValue }
}

private enum SplitPageSubMode: String, CaseIterable, Identifiable {
    case all = "All Pages", select = "Select"
    var id: String { rawValue }
}

private enum SizeUnit: String, CaseIterable, Identifiable {
    case kb = "KB", mb = "MB"
    var id: String { rawValue }
}

struct SplitPDFView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pageCount = 0

    @AppStorage("split.topMode") private var topMode: SplitTopMode = .range
    @AppStorage("split.rangeSubMode") private var rangeSubMode: SplitRangeSubMode = .custom
    @AppStorage("split.pageSubMode") private var pageSubMode: SplitPageSubMode = .all

    @State private var customRanges: [String] = [""]
    @State private var fixedEveryN: Int = 1

    @State private var selectedPages = Set<Int>()

    @AppStorage("split.maxSizeValue") private var maxSizeValue: Double = 5
    @AppStorage("split.sizeUnit") private var sizeUnit: SizeUnit = .mb
    @AppStorage("split.allowCompression") private var allowCompression = false

    @AppStorage("split.mergeIntoOne") private var mergeIntoOne = false
    @State private var outputTitle = "Split PDF"

    @State private var savedParts: [DocumentRecord] = []
    @State private var mergedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                if pageCount > 0 {
                    LabeledContent("Pages", value: "\(pageCount)")
                }
            }

            Section("Split Mode") {
                Picker("Mode", selection: $topMode) {
                    ForEach(SplitTopMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: topMode) { _, _ in clearResults() }
            }

            if topMode == .range { rangeSection }
            if topMode == .page { pageSection }
            if topMode == .size { sizeSection }

            Section {
                Toggle("Merge into one PDF", isOn: $mergeIntoOne)
                if mergeIntoOne {
                    TextField("Output name", text: $outputTitle)
                }
            } header: { Text("Output") } footer: {
                Text(mergeIntoOne
                    ? "All parts are merged into a single PDF and saved to your library."
                    : "Each part is available as a separate file to share.")
            }

            Section {
                PrimaryButton(title: "Split PDF", systemImage: "scissors") { performSplit() }
                    .disabled(!canSplit)
            }

            if !savedParts.isEmpty {
                Section("Saved Parts") {
                    ForEach(Array(savedParts.enumerated()), id: \.offset) { index, doc in
                        let fileURL = FileStorageService.fileURL(for: doc.fileName)
                        HStack {
                            Label(doc.title, systemImage: "doc.fill")
                                .lineLimit(1)
                            Spacer()
                            ShareLink(item: fileURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Split PDF")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let u = urls.first, let pdf = PDFDocument(url: u) {
                    pageCount = pdf.pageCount
                    fixedEveryN = max(1, pageCount / 2)
                }
                clearResults()
                customRanges = [""]
                selectedPages = []
                outputTitle = sourceURL?.deletingPathExtension().lastPathComponent ?? "Split PDF"
            }
        }
        .navigationDestination(item: $mergedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Splitting PDF") } }
        .alert("Split PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: – Range section

    @ViewBuilder private var rangeSection: some View {
        Section("Range Mode") {
            Picker("", selection: $rangeSubMode) {
                ForEach(SplitRangeSubMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        if rangeSubMode == .custom {
            Section {
                ForEach(customRanges.indices, id: \.self) { i in
                    HStack {
                        TextField("e.g. 1-3", text: $customRanges[i])
                            .keyboardType(.numbersAndPunctuation)
                        if customRanges.count > 1 {
                            Button { customRanges.remove(at: i) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    customRanges.append("")
                } label: {
                    Label("Add Range", systemImage: "plus.circle")
                        .foregroundStyle(AppTheme.primary)
                }
            } header: { Text("Page Ranges") } footer: {
                Text("Each range (e.g. \"1-3\") becomes a separate PDF. Pages are numbered from 1.")
            }
        } else {
            Section {
                Stepper(
                    "Every \(fixedEveryN) page\(fixedEveryN == 1 ? "" : "s")",
                    value: $fixedEveryN,
                    in: 1...max(1, pageCount > 0 ? pageCount : 1)
                )
                if pageCount > 0 {
                    LabeledContent("Resulting parts",
                        value: "\(Int(ceil(Double(pageCount) / Double(fixedEveryN))))")
                }
            } header: { Text("Fixed Split") } footer: {
                Text("Splits the PDF every \(fixedEveryN) page\(fixedEveryN == 1 ? "" : "s").")
            }
        }
    }

    // MARK: – Page section

    @ViewBuilder private var pageSection: some View {
        Section("Page Mode") {
            Picker("", selection: $pageSubMode) {
                ForEach(SplitPageSubMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        if pageSubMode == .all {
            Section {
                if pageCount > 0 {
                    LabeledContent("Output parts", value: "\(pageCount) PDFs")
                }
            } header: { Text("Extract All Pages") } footer: {
                Text("Every page becomes its own single-page PDF.")
            }
        } else if pageCount > 0 {
            Section {
                Text(selectedPages.isEmpty ? "Tap pages to select" : "\(selectedPages.count) page(s) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 14) {
                    ForEach(0..<pageCount, id: \.self) { idx in
                        if let sourceURL {
                            PageThumbnailChip(
                                pdfURL: sourceURL,
                                index: idx,
                                isSelected: selectedPages.contains(idx)
                            ) {
                                if selectedPages.contains(idx) { selectedPages.remove(idx) }
                                else { selectedPages.insert(idx) }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: { Text("Select Pages") } footer: {
                Text("Each page becomes a separate PDF. Enable \"Merge into one PDF\" to combine them in order.")
            }
        }
    }

    // MARK: – Size section

    @ViewBuilder private var sizeSection: some View {
        Section {
            HStack {
                Text("Max size per file")
                Spacer()
                TextField("5", value: $maxSizeValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Picker("", selection: $sizeUnit) {
                    ForEach(SizeUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 96)
            }
            Toggle("Allow compression", isOn: $allowCompression)
        } header: { Text("Size Limit") } footer: {
            Text("Pages accumulate until adding the next would exceed the limit. Compression reduces quality to help reach the target.")
        }
    }

    // MARK: – Validation

    private var canSplit: Bool {
        guard sourceURL != nil, pageCount > 0 else { return false }
        switch topMode {
        case .range:
            if rangeSubMode == .custom {
                return customRanges.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }
            return true
        case .page:
            return pageSubMode == .all || !selectedPages.isEmpty
        case .size:
            return maxSizeValue > 0
        }
    }

    private func clearResults() {
        savedParts = []
        mergedDocument = nil
    }

    // MARK: – Split logic

    private func performSplit() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            clearResults()
            do {
                let parts = try await buildParts(from: sourceURL)
                guard !parts.isEmpty else {
                    errorMessage = "No parts were produced. Check your settings."
                    return
                }
                if mergeIntoOne {
                    let merged = try await PDFProcessingService.shared.merge(parts: parts)
                    mergedDocument = try await SaveDocumentHelper.savePDF(
                        data: merged, title: outputTitle, modelContext: modelContext)
                } else {
                    let base = sourceURL.deletingPathExtension().lastPathComponent
                    var records: [DocumentRecord] = []
                    for (index, data) in parts.enumerated() {
                        let title = "\(base) – Part \(index + 1)"
                        let record = try await SaveDocumentHelper.savePDF(
                            data: data, title: title, modelContext: modelContext)
                        records.append(record)
                    }
                    savedParts = records
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func buildParts(from url: URL) async throws -> [Data] {
        switch topMode {
        case .range:
            switch rangeSubMode {
            case .custom:
                let str = customRanges
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                return try await PDFProcessingService.shared.split(url: url, rangesString: str)
            case .fixed:
                return try await PDFProcessingService.shared.splitFixed(url: url, everyNPages: fixedEveryN)
            }
        case .page:
            switch pageSubMode {
            case .all:
                return try await PDFProcessingService.shared.splitAllPages(url: url)
            case .select:
                let indexes = Array(selectedPages).sorted()
                return try await PDFProcessingService.shared.splitSelectedPages(url: url, pageIndexes: indexes)
            }
        case .size:
            let maxBytes = sizeUnit == .kb
                ? Int(maxSizeValue * 1024)
                : Int(maxSizeValue * 1024 * 1024)
            return try await PDFProcessingService.shared.splitBySize(
                url: url, maxBytes: maxBytes, allowCompression: allowCompression)
        }
    }
}
