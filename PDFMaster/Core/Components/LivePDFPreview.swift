import PDFKit
import SwiftUI

struct LivePDFPreview: View {
    let document: PDFDocument?
    let originalURL: URL
    let isProcessing: Bool

    var body: some View {
        ZStack {
            if let document {
                PDFKitDocumentView(document: document, autoScales: true)
            } else {
                PDFKitView(url: originalURL)
                    .opacity(0.35)
                    .allowsHitTesting(false)
            }

            if isProcessing {
                VStack {
                    HStack { Spacer(); ProgressView().padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6)) }.padding(8)
                    Spacer()
                }
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
