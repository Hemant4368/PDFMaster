import PencilKit
import SwiftUI

struct SavedSignature: Identifiable, Codable {
    var id: AnnotationID
    var drawingData: Data
    var name: String
    var date: Date
}

struct PDFSignatureSheet: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    @State private var canvasView = PKCanvasView()
    @State private var savedSignatures: [SavedSignature]
    @State private var signatureName = ""
    @State private var typedSignature = ""
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    private let storageKey = "com.pdfmaster.savedSignatures"

    init(viewModel: PDFEditorViewModel) {
        self.viewModel = viewModel
        if let data = UserDefaults.standard.data(forKey: "com.pdfmaster.savedSignatures"),
           let sigs = try? JSONDecoder().decode([SavedSignature].self, from: data) {
            _savedSignatures = State(initialValue: sigs)
        } else {
            _savedSignatures = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedTab) {
                    Text("Draw").tag(0)
                    Text("Type").tag(1)
                    if !savedSignatures.isEmpty {
                        Text("Saved").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    drawTab
                } else if selectedTab == 1 {
                    typeTab
                } else {
                    savedTab
                }
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySignature()
                        dismiss()
                    }
                    .disabled(selectedTab == 1 && typedSignature.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var drawTab: some View {
        VStack(spacing: 12) {
            PencilCanvasView(canvasView: $canvasView)
                .frame(height: 220)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            HStack {
                TextField("Signature name (optional)", text: $signatureName)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { saveSignature() }
                    .buttonStyle(.borderedProminent)
                    .disabled(canvasView.drawing.bounds.isEmpty)
            }
            .padding(.horizontal)

            Button("Clear", role: .destructive) {
                canvasView.drawing = PKDrawing()
            }
            .padding(.horizontal)
        }
    }

    private var typeTab: some View {
        VStack(spacing: 12) {
            Text("Type your signature below")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Signature", text: $typedSignature)
                .font(.custom("Zapfino", size: 32))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            Text("Will be rendered as a signature stamp")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var savedTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(savedSignatures) { sig in
                    Button {
                        selectSavedSignature(sig)
                        dismiss()
                    } label: {
                        VStack {
                            if let image = signatureImage(from: sig.drawingData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                                    .padding(8)
                            }
                            Text(sig.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func applySignature() {
        switch selectedTab {
        case 0:
            guard !canvasView.drawing.bounds.isEmpty else { return }
            let image = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: UITraitCollection.current.displayScale)
            viewModel.pendingSignatureImage = image
            viewModel.editorMode = .stamp
        case 1:
            guard !typedSignature.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            let text = typedSignature.trimmingCharacters(in: .whitespaces)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 80))
            let image = renderer.image { ctx in
                UIColor.black.setFill()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Zapfino", size: 36) ?? .systemFont(ofSize: 36),
                    .foregroundColor: UIColor.black,
                ]
                text.draw(at: CGPoint(x: 20, y: 20), withAttributes: attrs)
            }
            viewModel.pendingSignatureImage = image
            viewModel.editorMode = .stamp
        default:
            break
        }
    }

    private func saveSignature() {
        guard !canvasView.drawing.bounds.isEmpty else { return }
        let data = canvasView.drawing.dataRepresentation()
        let sig = SavedSignature(
            id: AnnotationID(),
            drawingData: data,
            name: signatureName.isEmpty ? "Signature \(savedSignatures.count + 1)" : signatureName,
            date: Date()
        )
        savedSignatures.append(sig)
        saveToUserDefaults()
        signatureName = ""
        canvasView.drawing = PKDrawing()
    }

    private func selectSavedSignature(_ sig: SavedSignature) {
        if let drawing = try? PKDrawing(data: sig.drawingData) {
            let image = drawing.image(from: drawing.bounds, scale: UITraitCollection.current.displayScale)
            viewModel.pendingSignatureImage = image
            viewModel.editorMode = .stamp
        }
    }

    private func signatureImage(from data: Data) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data) else { return nil }
        return drawing.image(from: drawing.bounds, scale: UITraitCollection.current.displayScale)
    }

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(savedSignatures) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
