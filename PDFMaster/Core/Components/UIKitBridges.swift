import PDFKit
import PencilKit
import SwiftUI
import UIKit
import VisionKit

struct PDFKitView: UIViewRepresentable {
    let url: URL
    var displayMode: PDFDisplayMode = .singlePageContinuous
    var autoScales = true

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = displayMode
        view.displayDirection = .vertical
        view.autoScales = autoScales
        view.backgroundColor = .systemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

struct EditablePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    let reloadToken: UUID

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = .systemBackground
        view.document = document
        context.coordinator.pdfView = view
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if context.coordinator.reloadToken != reloadToken || uiView.document !== document {
            context.coordinator.reloadToken = reloadToken
            uiView.document = document
            uiView.autoScales = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPageIndex: $currentPageIndex, reloadToken: reloadToken)
    }

    final class Coordinator: NSObject {
        @Binding var currentPageIndex: Int
        weak var pdfView: PDFView?
        var reloadToken: UUID

        init(currentPageIndex: Binding<Int>, reloadToken: UUID) {
            _currentPageIndex = currentPageIndex
            self.reloadToken = reloadToken
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView, let page = pdfView.currentPage, let index = pdfView.document?.index(for: page) else { return }
            currentPageIndex = index
        }
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true) { self.onComplete(images) }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true, completion: onCancel)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true, completion: onCancel)
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    var contentTypes: [UTTypeWrapper] = [.pdf]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes.map(\.type), asCopy: true)
        controller.allowsMultipleSelection = allowsMultipleSelection
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvasView.backgroundColor = .clear
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

struct PrintController {
    static func printPDF(url: URL) {
        let controller = UIPrintInteractionController.shared
        controller.printingItem = url
        controller.present(animated: true)
    }
}
