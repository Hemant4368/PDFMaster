import PDFKit
import PencilKit
import SwiftData
import SwiftUI

struct SignatureToolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SignatureRecord.createdAt, order: .reverse) private var signatures: [SignatureRecord]
    @State private var canvas = PKCanvasView()
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var pageIndex = 0
    @State private var signatureRect = CGRect(x: 120, y: 180, width: 240, height: 90)
    @State private var title = "Signed PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Create Signature") {
                PencilCanvasView(canvasView: $canvas)
                    .frame(height: 180)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Save Signature") { saveSignature() }
            }
            Section("Apply to PDF") {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                Stepper("Page \(pageIndex + 1)", value: $pageIndex, in: 0...999)
                TextField("Output name", text: $title)
                HStack {
                    Text("Width")
                    Slider(value: widthBinding, in: 80...420)
                }
                HStack {
                    Text("Height")
                    Slider(value: heightBinding, in: 40...180)
                }
                PrimaryButton(title: "Add Signature", systemImage: "signature") { applySignature() }
                    .disabled(sourceURL == nil || canvas.drawing.bounds.isEmpty)
            }
            if !signatures.isEmpty {
                Section("Saved Signatures") {
                    ForEach(signatures) { signature in
                        HStack {
                            if let image = UIImage(data: signature.imageData) {
                                Image(uiImage: image).resizable().scaledToFit().frame(height: 44)
                            }
                            Text(signature.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Signatures")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Signature", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var widthBinding: Binding<CGFloat> {
        Binding(
            get: { signatureRect.size.width },
            set: { signatureRect.size.width = $0 }
        )
    }

    private var heightBinding: Binding<CGFloat> {
        Binding(
            get: { signatureRect.size.height },
            set: { signatureRect.size.height = $0 }
        )
    }

    private func signatureImage() -> UIImage? {
        let bounds = canvas.drawing.bounds.insetBy(dx: -20, dy: -20)
        guard !bounds.isEmpty else { return nil }
        return canvas.drawing.image(from: bounds, scale: UIScreen.main.scale)
    }

    private func saveSignature() {
        guard let image = signatureImage(), let data = image.pngData() else { return }
        modelContext.insert(SignatureRecord(name: "Signature \(signatures.count + 1)", imageData: data))
        try? modelContext.save()
    }

    private func applySignature() {
        guard let sourceURL, let image = signatureImage() else { return }
        Task {
            do {
                let data = try await PDFProcessingService.shared.signed(url: sourceURL, signature: image, pageIndex: max(0, pageIndex), rect: signatureRect)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
