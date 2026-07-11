import PDFKit
import PencilKit
import QuickLook
import SwiftUI
import UIKit
import VisionKit
import WebKit

// MARK: — PDFKitView

struct PDFKitView: UIViewRepresentable {
    let url: URL
    var displayMode: PDFDisplayMode = .singlePageContinuous
    var autoScales = true
    var allowsDocumentInteraction = true

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = displayMode
        view.displayDirection = .vertical
        view.autoScales = autoScales
        view.backgroundColor = .systemBackground
        view.isUserInteractionEnabled = allowsDocumentInteraction
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// MARK: — EditablePDFKitView

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
            guard let pdfView,
                  let page = pdfView.currentPage,
                  let index = pdfView.document?.index(for: page) else { return }
            currentPageIndex = index
        }
    }
}

// MARK: — DocumentScannerView

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

// MARK: — DocumentPickerView

struct DocumentPickerView: UIViewControllerRepresentable {
    var contentTypes: [UTTypeWrapper] = [.pdf]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes.map(\.type),
            asCopy: true
        )
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

// MARK: — ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: — PencilCanvasView

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

// MARK: — PrintController

struct PrintController {
    static func printPDF(url: URL) {
        let controller = UIPrintInteractionController.shared
        controller.printingItem = url
        controller.present(animated: true)
    }
}

// MARK: — QLPreviewControllerView (Office file preview)

struct QLPreviewControllerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: — WebPreviewView

struct WebPreviewView: UIViewRepresentable {
    let urlString: String
    let screenSize: HTMLScreenSize
    let refreshTrigger: UUID

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let agent = screenSize.width > 500
            ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
            : "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        wv.customUserAgent = agent
        let key = urlString + refreshTrigger.uuidString
        guard key != context.coordinator.lastKey,
              let url = URL(string: urlString), !urlString.isEmpty, urlString != "https://" else { return }
        context.coordinator.lastKey = key
        wv.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, WKNavigationDelegate { var lastKey = "" }
}

// MARK: — HTMLPDFRenderer (WKWebView → PDF Data)

@MainActor
final class HTMLPDFRenderer: NSObject {
    private var continuation: CheckedContinuation<Data, Error>?
    private var webView: WKWebView?
    private var options = RenderOptions()

    struct RenderOptions {
        var viewportWidth: CGFloat = 1440
        var pageSize: HTMLPageSize = .a4
        var oneLongPage: Bool = false
        var orientation: PDFPageOrientation = .portrait
        var margin: PDFMarginSize = .none
        var blockAds: Bool = false
        var removePopups: Bool = false
    }

    static func render(
        htmlString: String? = nil, pageURL: URL? = nil,
        options: RenderOptions = RenderOptions()
    ) async throws -> Data {
        let r = HTMLPDFRenderer(); r.options = options
        return try await r.start(htmlString: htmlString, pageURL: pageURL)
    }

    private func start(htmlString: String?, pageURL: URL?) async throws -> Data {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let cfg = WKWebViewConfiguration()
            let uc = WKUserContentController()
            if options.blockAds {
                uc.addUserScript(WKUserScript(source: Self.adBlockCSS, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
            }
            if options.removePopups {
                uc.addUserScript(WKUserScript(source: Self.popupBlockCSS, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
            }
            cfg.userContentController = uc
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: options.viewportWidth, height: 842), configuration: cfg)
            if options.viewportWidth > 500 {
                wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
            }
            wv.navigationDelegate = self
            self.webView = wv
            if let html = htmlString { wv.loadHTMLString(html, baseURL: nil) }
            else if let url = pageURL { wv.load(URLRequest(url: url)) }
            else { cont.resume(throwing: URLError(.badURL)); self.continuation = nil }
        }
    }

    private func handleFinish(wv: WKWebView) {
        Task { @MainActor in
            var paper = options.pageSize.paperRect(orientation: options.orientation)
            if options.oneLongPage,
               let h = try? await wv.evaluateJavaScript("document.documentElement.scrollHeight") as? CGFloat,
               h > 0 {
                paper = CGRect(origin: .zero, size: CGSize(width: paper.width, height: h))
            }
            let m = options.margin.points
            let printable = paper.insetBy(dx: m, dy: m)
            let renderer = UIPrintPageRenderer()
            renderer.addPrintFormatter(wv.viewPrintFormatter(), startingAtPageAt: 0)
            renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
            renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")
            renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, paper, nil)
            for i in 0..<renderer.numberOfPages {
                UIGraphicsBeginPDFPage()
                renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
            }
            UIGraphicsEndPDFContext()
            finish(result: pdfData.length > 0 ? .success(pdfData as Data) : .failure(PDFProcessingError.writeFailed))
        }
    }

    private func finish(result: Result<Data, Error>) {
        switch result {
        case .success(let d): continuation?.resume(returning: d)
        case .failure(let e): continuation?.resume(throwing: e)
        }
        continuation = nil; webView?.navigationDelegate = nil; webView = nil
    }

    private static let adBlockCSS = """
    var s=document.createElement('style');
    s.textContent='[class*="ad"],[id*="ad"],[class*="banner"],[class*="sponsor"],ins.adsbygoogle,.ads,.ad-container{display:none!important}';
    document.documentElement.appendChild(s);
    """

    private static let popupBlockCSS = """
    var s=document.createElement('style');
    s.textContent='*[style*="position:fixed"],*[style*="position: fixed"],*[style*="position:sticky"],*[style*="position: sticky"]{display:none!important}body{overflow:visible!important}';
    document.documentElement.appendChild(s);
    """
}

extension HTMLPDFRenderer: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.handleFinish(wv: webView) }
    }
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(result: .failure(error)) }
    }
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(result: .failure(error)) }
    }
}
