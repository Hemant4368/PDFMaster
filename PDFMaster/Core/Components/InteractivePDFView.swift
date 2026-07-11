import PDFKit
import PencilKit
import SwiftUI

// MARK: — Gesture mode driven by editor state

enum PDFGestureMode {
    case normal      // PDFView handles all input (view + markup selection)
    case tapToPlace  // Overlay intercepts taps (text / stamp / note)
    case shapeDraw   // Overlay intercepts pan for rubber-band shapes
    case pencilDraw  // PKCanvasView is layered on top for PencilKit drawing
}

// MARK: — UIViewRepresentable

struct InteractivePDFView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    let reloadToken: UUID
    let gestureMode: PDFGestureMode
    var strokeColor: UIColor = .systemYellow
    var strokeWidth: CGFloat = 2
    @Binding var pencilCanvas: PKCanvasView
    let onTap: (CGPoint, PDFPage) -> Void
    let onShapeDrag: (CGRect, PDFPage) -> Void
    let onSelectionChanged: (PDFSelection?) -> Void
    let onViewReady: (PDFView) -> Void

    // MARK: makeUIView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground

        // ── PDFView ──────────────────────────────────────────────────────────
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGroupedBackground
        pdfView.document = document
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.pdfView = pdfView
        onViewReady(pdfView)

        // ── Notifications ─────────────────────────────────────────────────────
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged, object: pdfView)

        // ── Gesture overlay ───────────────────────────────────────────────────
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        container.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.overlay = overlay

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        overlay.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        let pan = UIPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        overlay.addGestureRecognizer(pan)
        context.coordinator.panGesture = pan

        // Shape preview layer
        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.fillColor = strokeColor.withAlphaComponent(0.08).cgColor
        shapeLayer.lineWidth = strokeWidth
        shapeLayer.lineDashPattern = [6, 3]
        shapeLayer.isHidden = true
        overlay.layer.addSublayer(shapeLayer)
        context.coordinator.shapeLayer = shapeLayer
        context.coordinator.container = container

        // Sync callbacks & mode
        context.coordinator.onTap = onTap
        context.coordinator.onShapeDrag = onShapeDrag
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.applyGestureMode(gestureMode, canvas: pencilCanvas)

        return container
    }

    // MARK: updateUIView

    func updateUIView(_ container: UIView, context: Context) {
        let c = context.coordinator
        if c.pdfView?.document !== document || c.reloadToken != reloadToken {
            c.reloadToken = reloadToken
            c.pdfView?.document = document
            c.pdfView?.autoScales = true
        }
        c.onTap = onTap
        c.onShapeDrag = onShapeDrag
        c.onSelectionChanged = onSelectionChanged
        c.shapeLayer?.strokeColor = strokeColor.cgColor
        c.shapeLayer?.fillColor = strokeColor.withAlphaComponent(0.08).cgColor
        c.shapeLayer?.lineWidth = strokeWidth
        c.applyGestureMode(gestureMode, canvas: pencilCanvas)
        if let pv = c.pdfView { onViewReady(pv) }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pageIndex: $currentPageIndex, reloadToken: reloadToken,
                    onTap: onTap, onShapeDrag: onShapeDrag, onSelectionChanged: onSelectionChanged)
    }

    // MARK: — Coordinator

    final class Coordinator: NSObject {
        @Binding var currentPageIndex: Int
        var reloadToken: UUID
        weak var pdfView: PDFView?
        weak var overlay: UIView?
        weak var container: UIView?
        var shapeLayer: CAShapeLayer?
        var tapGesture: UITapGestureRecognizer?
        var panGesture: UIPanGestureRecognizer?
        var pencilCanvas: PKCanvasView?
        var panStart: CGPoint?
        var currentMode: PDFGestureMode = .normal

        var onTap: (CGPoint, PDFPage) -> Void
        var onShapeDrag: (CGRect, PDFPage) -> Void
        var onSelectionChanged: (PDFSelection?) -> Void

        init(pageIndex: Binding<Int>, reloadToken: UUID,
             onTap: @escaping (CGPoint, PDFPage) -> Void,
             onShapeDrag: @escaping (CGRect, PDFPage) -> Void,
             onSelectionChanged: @escaping (PDFSelection?) -> Void) {
            _currentPageIndex = pageIndex
            self.reloadToken = reloadToken
            self.onTap = onTap; self.onShapeDrag = onShapeDrag; self.onSelectionChanged = onSelectionChanged
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        // ── Mode switching ────────────────────────────────────────────────────

        func applyGestureMode(_ mode: PDFGestureMode, canvas: PKCanvasView) {
            currentMode = mode
            switch mode {
            case .normal:
                overlay?.isUserInteractionEnabled = false
                removePencilCanvas()
            case .tapToPlace:
                overlay?.isUserInteractionEnabled = true
                tapGesture?.isEnabled = true
                panGesture?.isEnabled = false
                removePencilCanvas()
            case .shapeDraw:
                overlay?.isUserInteractionEnabled = true
                tapGesture?.isEnabled = false
                panGesture?.isEnabled = true
                removePencilCanvas()
            case .pencilDraw:
                overlay?.isUserInteractionEnabled = false
                addPencilCanvas(canvas)
            }
        }

        private func addPencilCanvas(_ canvas: PKCanvasView) {
            guard let container else { return }
            pencilCanvas = canvas
            canvas.translatesAutoresizingMaskIntoConstraints = false
            canvas.backgroundColor = .clear
            canvas.drawingPolicy = .anyInput
            canvas.isOpaque = false
            container.addSubview(canvas)
            NSLayoutConstraint.activate([
                canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                canvas.topAnchor.constraint(equalTo: container.topAnchor),
                canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        private func removePencilCanvas() {
            pencilCanvas?.removeFromSuperview()
            pencilCanvas = nil
        }

        // ── Notifications ─────────────────────────────────────────────────────

        @objc func pageChanged(_ note: Notification) {
            guard let pv = pdfView,
                  let page = pv.currentPage,
                  let idx = pv.document?.index(for: page) else { return }
            DispatchQueue.main.async { self.currentPageIndex = idx }
        }

        @objc func selectionChanged(_ note: Notification) {
            guard let pv = pdfView else { return }
            DispatchQueue.main.async { self.onSelectionChanged(pv.currentSelection) }
        }

        // ── Tap ───────────────────────────────────────────────────────────────

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let pv = pdfView else { return }
            let viewPt = g.location(in: pv)
            guard let page = pv.page(for: viewPt, nearest: true) else { return }
            let pagePt = pv.convert(viewPt, to: page)
            DispatchQueue.main.async { self.onTap(pagePt, page) }
        }

        // ── Pan (shape rubber-band) ────────────────────────────────────────────

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let ov = overlay, let pv = pdfView else { return }
            let pt = g.location(in: ov)

            switch g.state {
            case .began:
                panStart = pt
                shapeLayer?.isHidden = false

            case .changed:
                guard let s = panStart else { return }
                let r = CGRect(x: min(s.x, pt.x), y: min(s.y, pt.y),
                               width: abs(pt.x - s.x), height: abs(pt.y - s.y))
                shapeLayer?.frame = ov.bounds
                shapeLayer?.path = UIBezierPath(rect: r).cgPath

            case .ended, .cancelled:
                shapeLayer?.isHidden = true
                shapeLayer?.path = nil
                guard let s = panStart else { return }
                panStart = nil
                // Convert overlay → pdfView → page coordinates
                let startInPV = ov.convert(s, to: pv)
                let endInPV   = ov.convert(pt, to: pv)
                guard let page = pv.page(for: startInPV, nearest: true) else { return }
                let pageS = pv.convert(startInPV, to: page)
                let pageE = pv.convert(endInPV, to: page)
                let rect = CGRect(x: min(pageS.x, pageE.x), y: min(pageS.y, pageE.y),
                                  width: abs(pageE.x - pageS.x), height: abs(pageE.y - pageS.y))
                guard rect.width > 4, rect.height > 4 else { return }
                DispatchQueue.main.async { self.onShapeDrag(rect, page) }

            default: break
            }
        }
    }
}
