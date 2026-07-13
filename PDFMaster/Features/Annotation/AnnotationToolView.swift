import PDFKit
import SwiftData
import SwiftUI

struct AnnotationToolView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var title = "Annotated PDF"
    @State private var noteText = "Note"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?
    @AppStorage("annotation.defaultColorHex") private var defaultColorHex = "#FF0000"
    @AppStorage("annotation.highlightOpacity") private var highlightOpacity: Double = 0.5

    private var defaultColor: Color {
        get { Color(hex: defaultColorHex) ?? .red }
        nonmutating set { defaultColorHex = newValue.toHex() ?? "#FF0000" }
    }

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
                TextField("Note text", text: $noteText)
            }
            Section("Default Style") {
                ColorPicker("Annotation Color", selection: Binding(
                    get: { defaultColor },
                    set: { defaultColor = $0 }
                ))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highlight Opacity: \(highlightOpacity, specifier: "%.1f")")
                    Slider(value: $highlightOpacity, in: 0.1...1.0)
                }
            }
            if let sourceURL {
                Section("Preview") {
                    PDFKitView(url: sourceURL).frame(height: 360)
                }
            }
            Section {
                PrimaryButton(title: "Add Highlight", systemImage: "highlighter") { annotate(.highlight) }
                PrimaryButton(title: "Add Underline", systemImage: "underline") { annotate(.underline) }
                PrimaryButton(title: "Add Note", systemImage: "note.text") { annotate(.text) }
            }
        }
        .navigationTitle("Annotate PDF")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Annotation", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func annotate(_ subtype: PDFAnnotationSubtype) {
        guard let sourceURL, let pdf = PDFDocument(url: sourceURL), let page = pdf.page(at: 0) else { return }
        let bounds = page.bounds(for: .cropBox)
        let rect = CGRect(x: bounds.midX - 120, y: bounds.midY, width: 240, height: 42)
        let annotation = PDFAnnotation(bounds: rect, forType: subtype, withProperties: nil)
        annotation.color = subtype == .text ? UIColor(hex: defaultColorHex) ?? .systemYellow : AppTheme.primaryUIColor.withAlphaComponent(highlightOpacity)
        if subtype == .text { annotation.contents = noteText }
        page.addAnnotation(annotation)
        guard let data = pdf.dataRepresentation() else { return }
        Task {
            do {
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

extension AppTheme {
    static var primaryUIColor: UIColor { UIColor(red: 1.0, green: 0.168, blue: 0.168, alpha: 1) }
}

extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(hex), hex.count == 6 else { return nil }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
