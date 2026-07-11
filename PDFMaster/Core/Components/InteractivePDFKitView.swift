import PDFKit
import PencilKit
import SwiftUI

struct InteractivePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    let reloadToken: UUID
    let editorViewModel: PDFEditorViewModel

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemBackground
        pdfView.document = document
        container.addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let canvas = PKCanvasView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isUserInteractionEnabled = false
        container.addSubview(canvas)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: container.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let gestureOverlay = UIView()
        gestureOverlay.translatesAutoresizingMaskIntoConstraints = false
        gestureOverlay.backgroundColor = .clear
        gestureOverlay.isUserInteractionEnabled = false
        container.addSubview(gestureOverlay)

        NSLayoutConstraint.activate([
            gestureOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            gestureOverlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gestureOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gestureOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let shapePreview = CAShapeLayer()
        shapePreview.strokeColor = UIColor.yellow.cgColor
        shapePreview.fillColor = UIColor.clear.cgColor
        shapePreview.lineWidth = 2
        shapePreview.lineDashPattern = [6, 4]
        shapePreview.isHidden = true
        gestureOverlay.layer.addSublayer(shapePreview)

        let coordinator = context.coordinator
        coordinator.pdfView = pdfView
        coordinator.canvasView = canvas
        coordinator.gestureOverlay = gestureOverlay
        coordinator.shapePreview = shapePreview
        coordinator.editorViewModel = editorViewModel

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coordinator
        gestureOverlay.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = coordinator
        gestureOverlay.addGestureRecognizer(pan)

        context.coordinator.updateMode(editorViewModel.gestureMode, pdfView: pdfView)
        editorViewModel.pdfView = pdfView

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let pdfView = context.coordinator.pdfView else { return }
        if context.coordinator.reloadToken != reloadToken || pdfView.document !== document {
            context.coordinator.reloadToken = reloadToken
            pdfView.document = document
            pdfView.autoScales = true
        }
        context.coordinator.editorViewModel = editorViewModel
        context.coordinator.updateMode(editorViewModel.gestureMode, pdfView: pdfView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPageIndex: $currentPageIndex, reloadToken: reloadToken)
    }

    final class Coordinator: NSObject {
        @Binding var currentPageIndex: Int
        var reloadToken: UUID
        weak var pdfView: PDFView?
        weak var canvasView: PKCanvasView?
        weak var gestureOverlay: UIView?
        weak var shapePreview: CAShapeLayer?
        var editorViewModel: PDFEditorViewModel?
        private var shapeStart: CGPoint = .zero
        private var lastMode: GestureMode?

        init(currentPageIndex: Binding<Int>, reloadToken: UUID) {
            _currentPageIndex = currentPageIndex
            self.reloadToken = reloadToken
        }

        func updateMode(_ mode: GestureMode, pdfView: PDFView) {
            let previousMode = lastMode
            lastMode = mode

            if previousMode == .pencil && mode != .pencil {
                bakeCanvasDrawing()
            }

            switch mode {
            case .normal:
                pdfView.isUserInteractionEnabled = true
                gestureOverlay?.isUserInteractionEnabled = false
                canvasView?.isUserInteractionEnabled = false
                shapePreview?.isHidden = true
            case .tapToPlace:
                pdfView.isUserInteractionEnabled = false
                gestureOverlay?.isUserInteractionEnabled = true
                canvasView?.isUserInteractionEnabled = false
                shapePreview?.isHidden = true
            case .shapeDraw:
                pdfView.isUserInteractionEnabled = false
                gestureOverlay?.isUserInteractionEnabled = true
                canvasView?.isUserInteractionEnabled = false
                shapePreview?.isHidden = false
            case .pencil:
                pdfView.isUserInteractionEnabled = false
                gestureOverlay?.isUserInteractionEnabled = false
                canvasView?.isUserInteractionEnabled = true
                canvasView?.drawingPolicy = .pencilOnly
                shapePreview?.isHidden = true
            }
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView, let page = pdfView.currentPage, let index = pdfView.document?.index(for: page) else { return }
            currentPageIndex = index
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let pdfView, let page = pdfView.currentPage else { return }
            let location = gesture.location(in: pdfView)
            let pagePoint = pdfView.convert(location, to: page)
            Task { @MainActor [weak self] in
                self?.editorViewModel?.handleTap(at: pagePoint, on: page)
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let pdfView, let preview = shapePreview else { return }
            let location = gesture.location(in: pdfView)

            switch gesture.state {
            case .began:
                shapeStart = location
                preview.isHidden = false
            case .changed:
                let rect = normalizedRect(from: shapeStart, to: location)
                preview.path = UIBezierPath(rect: rect).cgPath
                Task { @MainActor [weak self] in
                    guard let vm = self?.editorViewModel else { return }
                    preview.strokeColor = UIColor(vm.annotationColor).cgColor
                    preview.lineWidth = vm.lineWidth
                }
            case .ended:
                preview.isHidden = true
                guard let page = pdfView.currentPage else { return }
                let startPoint = pdfView.convert(shapeStart, to: page)
                let endPoint = pdfView.convert(location, to: page)
                let w = abs(endPoint.x - startPoint.x)
                let h = abs(endPoint.y - startPoint.y)
                let rect = CGRect(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y), width: w, height: h)
                Task { @MainActor [weak self] in
                    self?.editorViewModel?.handleShapeDrag(rect: rect, on: page)
                }
            default:
                preview.isHidden = true
            }
        }

        private func normalizedRect(from: CGPoint, to: CGPoint) -> CGRect {
            CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
        }

        private func bakeCanvasDrawing() {
            guard let canvasView, let pdfView, canvasView.drawing.bounds.isEmpty == false else { return }
            let drawing = canvasView.drawing
            canvasView.drawing = PKDrawing()

            let canvasToPage: (CGPoint) -> CGPoint = { [weak pdfView] point in
                guard let pdfView, let page = pdfView.currentPage else { return point }
                let inPDFView = canvasView.convert(point, to: pdfView)
                return pdfView.convert(inPDFView, to: page)
            }

            Task { @MainActor [weak self] in
                self?.editorViewModel?.bakeDrawing(drawing, canvasToPageTransform: canvasToPage)
            }
        }
    }
}

extension InteractivePDFKitView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
