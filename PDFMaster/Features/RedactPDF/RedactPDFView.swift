import PDFKit
import SwiftData
import SwiftUI

struct RedactPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pageCount = 0
    @State private var pageIndex = 0
    @State private var regionX: String = "50"
    @State private var regionY: String = "100"
    @State private var regionW: String = "200"
    @State private var regionH: String = "30"
    @State private var regions: [(pageIndex: Int, rect: CGRect)] = []
    @State private var title = "Redacted PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Input") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
            }

            if pageCount > 0 {
                if let url = sourceURL {
                    Section("Preview") {
                        PDFKitView(url: url)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Section {
                    Stepper("Page \(pageIndex + 1) of \(pageCount)", value: $pageIndex, in: 0...(pageCount - 1))
                    coordinateRow(label: "X", value: $regionX)
                    coordinateRow(label: "Y", value: $regionY)
                    coordinateRow(label: "Width", value: $regionW)
                    coordinateRow(label: "Height", value: $regionH)
                    Button("Add Redaction") { addRegion() }
                        .foregroundStyle(AppTheme.primary)
                } header: {
                    Text("Add Redaction Region")
                } footer: {
                    Text("Coordinates are in PDF points from the top-left corner of the page.")
                }

                if !regions.isEmpty {
                    Section("Pending Redactions (\(regions.count))") {
                        ForEach(regions.indices, id: \.self) { i in
                            let r = regions[i]
                            HStack {
                                Text("Page \(r.pageIndex + 1)")
                                Spacer()
                                Text("(\(Int(r.rect.minX)), \(Int(r.rect.minY))) \(Int(r.rect.width))×\(Int(r.rect.height))")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .onDelete { regions.remove(atOffsets: $0) }
                    }

                    Section {
                        PrimaryButton(title: "Apply Redactions", systemImage: "rectangle.fill.on.rectangle.fill") {
                            applyRedactions()
                        }
                    }
                }
            }
        }
        .navigationTitle("Redact PDF")
        .toolbar { if !regions.isEmpty { EditButton() } }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { urls in
                sourceURL = urls.first
                if let u = urls.first, let pdf = PDFDocument(url: u) { pageCount = pdf.pageCount }
                regions = []
                pageIndex = 0
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Applying Redactions") } }
        .alert("Redact PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private func coordinateRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            TextField("0", text: value)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
            Text("pt").foregroundStyle(.secondary)
        }
    }

    private func addRegion() {
        guard let x = Double(regionX), let y = Double(regionY),
              let w = Double(regionW), let h = Double(regionH),
              w > 0, h > 0 else {
            errorMessage = "Enter valid positive numbers for all coordinates."
            return
        }
        regions.append((pageIndex: pageIndex, rect: CGRect(x: x, y: y, width: w, height: h)))
    }

    private func applyRedactions() {
        guard let sourceURL else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                let data = try await PDFProcessingService.shared.redact(url: sourceURL, regions: regions)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
