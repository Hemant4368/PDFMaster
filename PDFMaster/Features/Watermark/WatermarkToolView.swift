import PDFKit
import SwiftData
import SwiftUI

struct WatermarkToolView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var options = WatermarkOptions()
    @State private var title = "Watermarked PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                TextField("Output name", text: $title)
                TextField("Watermark text", text: $options.text)
                Slider(value: $options.opacity, in: 0.05...0.85) { Text("Opacity") }
                Slider(value: $options.rotation, in: -60...60) { Text("Rotation") }
                Slider(value: $options.fontSize, in: 22...110) { Text("Font Size") }
                Picker("Position", selection: $options.position) {
                    ForEach(WatermarkPosition.allCases) { Text($0.rawValue).tag($0) }
                }
                ColorPicker("Color", selection: $options.color)
            }
            if let sourceURL {
                Section("Preview") {
                    PDFKitView(url: sourceURL)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            Text(options.text)
                                .font(.system(size: min(options.fontSize / 2, 42), weight: .heavy))
                                .foregroundStyle(options.color.opacity(options.opacity))
                                .rotationEffect(.degrees(options.rotation))
                        }
                }
            }
            Section {
                PrimaryButton(title: "Apply Watermark", systemImage: "stamp") { apply() }
                    .disabled(sourceURL == nil || options.text.isEmpty)
            }
        }
        .navigationTitle("Watermark")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Watermark", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func apply() {
        guard let sourceURL else { return }
        Task {
            do {
                let data = try await PDFProcessingService.shared.watermarked(url: sourceURL, options: options)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
