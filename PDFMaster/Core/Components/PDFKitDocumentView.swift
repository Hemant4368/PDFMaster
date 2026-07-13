import PDFKit
import SwiftUI

struct PDFKitDocumentView: UIViewRepresentable {
    let document: PDFDocument?
    var autoScales = true
    var displayMode: PDFDisplayMode = .singlePageContinuous

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = displayMode
        view.displayDirection = .vertical
        view.autoScales = autoScales
        view.backgroundColor = .systemBackground
        view.isUserInteractionEnabled = false
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}
