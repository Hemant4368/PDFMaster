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

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                TextField("Output name", text: $title)
                TextField("Note text", text: $noteText)
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
        annotation.color = subtype == .text ? .systemYellow : AppTheme.primaryUIColor.withAlphaComponent(0.35)
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
