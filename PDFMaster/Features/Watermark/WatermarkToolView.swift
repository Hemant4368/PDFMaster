import PDFKit
import SwiftData
import SwiftUI

struct WatermarkToolView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Watermarked PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?
    @AppStorage("watermark.text") private var text = "SAMPLE"
    @AppStorage("watermark.opacity") private var opacity: Double = 0.22
    @AppStorage("watermark.rotation") private var rotation: Double = -35
    @AppStorage("watermark.fontSize") private var fontSize: Double = 54
    @AppStorage("watermark.colorHex") private var colorHex = "#FF2B2B"
    @AppStorage("watermark.position") private var position: WatermarkPosition = .center

    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false

    private var watermarkColor: Color {
        get { Color(hex: colorHex) ?? AppTheme.primary }
        nonmutating set { colorHex = newValue.toHex() ?? "#FF2B2B" }
    }

    private var previewHash: Int {
        var h = Hasher()
        h.combine(text); h.combine(opacity); h.combine(rotation)
        h.combine(fontSize); h.combine(colorHex); h.combine(position)
        return h.finalize()
    }

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
                TextField("Watermark text", text: $text)
                Slider(value: $opacity, in: 0.05...0.85) { Text("Opacity") }
                Slider(value: $rotation, in: -60...60) { Text("Rotation") }
                Slider(value: $fontSize, in: 22...110) { Text("Font Size") }
                Picker("Position", selection: $position) {
                    ForEach(WatermarkPosition.allCases) { Text($0.rawValue).tag($0) }
                }
                ColorPicker("Color", selection: Binding(
                    get: { watermarkColor },
                    set: { watermarkColor = $0 }
                ))
            }
            if let sourceURL {
                Section("Preview") {
                    LivePDFPreview(document: previewDocument, originalURL: sourceURL, isProcessing: isPreparingPreview)
                }
            }
            Section {
                PrimaryButton(title: "Apply Watermark", systemImage: "stamp") { apply() }
                    .disabled(sourceURL == nil || text.isEmpty)
            }
        }
        .navigationTitle("Watermark")
        .task { if let url = shareInbox.consumeURL(for: .watermark) { sourceURL = url } }
        .task(id: previewHash) { await generatePreview() }
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Watermark", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func generatePreview() async {
        guard let url = sourceURL else { return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }
        do {
            let tempDoc = firstPageOnly(url: url)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            try tempDoc?.dataRepresentation()?.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let options = WatermarkOptions(text: text, opacity: opacity, rotation: rotation, fontSize: fontSize, color: watermarkColor, position: position)
            let data = try await PDFProcessingService.shared.watermarked(url: tempURL, options: options)
            previewDocument = PDFDocument(data: data)
        } catch {
            previewDocument = PDFDocument(url: url)
        }
    }

    private func firstPageOnly(url: URL) -> PDFDocument? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let single = PDFDocument()
        single.insert(page, at: 0)
        return single
    }

    private func apply() {
        guard let sourceURL else { return }
        Task {
            do {
                let options = WatermarkOptions(text: text, opacity: opacity, rotation: rotation, fontSize: fontSize, color: watermarkColor, position: position)
                let data = try await PDFProcessingService.shared.watermarked(url: sourceURL, options: options)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(hex), hex.count == 6 else { return nil }
        self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: 1)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
