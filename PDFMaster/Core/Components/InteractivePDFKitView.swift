import PDFKit
import PencilKit
import SwiftUI

struct InteractivePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    let reloadToken: UUID
    let editorViewModel: PDFEditorViewModel
    let isEditing: Bool

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

        let selRect = CAShapeLayer()
        selRect.strokeColor = UIColor.systemBlue.cgColor
        selRect.fillColor = UIColor.clear.cgColor
        selRect.lineWidth = 2
        selRect.lineDashPattern = [4, 3]
        selRect.isHidden = true
        gestureOverlay.layer.addSublayer(selRect)

        let resizeHandle = CAShapeLayer()
        resizeHandle.strokeColor = UIColor.systemBlue.cgColor
        resizeHandle.fillColor = UIColor.white.cgColor
        resizeHandle.lineWidth = 2
        resizeHandle.isHidden = true
        gestureOverlay.layer.addSublayer(resizeHandle)

        let coordinator = context.coordinator
        coordinator.pdfView = pdfView
        coordinator.canvasView = canvas
        coordinator.gestureOverlay = gestureOverlay
        coordinator.shapePreview = shapePreview
        coordinator.selectionRect = selRect
        coordinator.resizeHandle = resizeHandle
        coordinator.editorViewModel = editorViewModel

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coordinator
        pdfView.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = coordinator
        pdfView.addGestureRecognizer(doubleTap)

        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = coordinator
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pdfView.addGestureRecognizer(pan)

        let longPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.delegate = coordinator
        longPress.minimumPressDuration = 0.4
        pdfView.addGestureRecognizer(longPress)

        tap.require(toFail: doubleTap)

        context.coordinator.updateMode(editorViewModel.gestureMode, pdfView: pdfView)
        editorViewModel.pdfView = pdfView

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let pdfView = context.coordinator.pdfView else { return }
        let c = context.coordinator

        if c.reloadToken != reloadToken || pdfView.document !== document {
            c.reloadToken = reloadToken
            let savedScale = pdfView.scaleFactor
            let savedPage = pdfView.currentPage
            let savedBounds = savedPage?.bounds(for: .cropBox)

            pdfView.document = document

            if let savedPage, let savedBounds, savedPage !== pdfView.currentPage {
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i), page.bounds(for: .cropBox) == savedBounds {
                        pdfView.go(to: PDFDestination(page: page, at: .zero))
                        break
                    }
                }
            }
            if savedScale > 0 && savedScale < 10 {
                pdfView.scaleFactor = savedScale
            } else {
                pdfView.autoScales = true
            }
        }

        if let currentPage = pdfView.currentPage,
           let currentIdx = pdfView.document?.index(for: currentPage),
           currentIdx != currentPageIndex {
            if let targetPage = document.page(at: currentPageIndex) {
                pdfView.go(to: PDFDestination(page: targetPage, at: .zero))
            }
        }

        let newDisplayMode: PDFDisplayMode = isEditing ? .singlePage : .singlePageContinuous
        if pdfView.displayMode != newDisplayMode {
            let savedPage = pdfView.currentPage
            pdfView.displayMode = newDisplayMode
            if let savedPage, pdfView.currentPage !== savedPage {
                pdfView.go(to: PDFDestination(page: savedPage, at: .zero))
            }
        }

        c.editorViewModel = editorViewModel
        c.updateMode(editorViewModel.gestureMode, pdfView: pdfView)
        c.updateSelectionHighlight()
        if editorViewModel.gestureMode == .pencil {
            c.configureCanvasTool()
        }
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
        weak var selectionRect: CAShapeLayer?
        weak var resizeHandle: CAShapeLayer?
        var editorViewModel: PDFEditorViewModel?
        private var shapeStart: CGPoint = .zero
        private var lastMode: GestureMode?
        private var isDraggingAnnotation = false
        private var dragStartAnnotationBounds: CGRect?
        private var dragStartPoint: CGPoint = .zero
        private weak var dragAnnotation: PDFAnnotation?
        private var isResizing = false
        private var resizeCorner: Int = 0

        init(currentPageIndex: Binding<Int>, reloadToken: UUID) {
            _currentPageIndex = currentPageIndex
            self.reloadToken = reloadToken
        }

        deinit {
            if let pdfView {
                NotificationCenter.default.removeObserver(self, name: .PDFViewPageChanged, object: pdfView)
            }
        }

        @MainActor func updateMode(_ mode: GestureMode, pdfView: PDFView) {
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
                selectionRect?.isHidden = true
            case .shapeDraw:
                pdfView.isUserInteractionEnabled = false
                gestureOverlay?.isUserInteractionEnabled = true
                canvasView?.isUserInteractionEnabled = false
                shapePreview?.isHidden = false
                selectionRect?.isHidden = true
            case .pencil:
                pdfView.isUserInteractionEnabled = false
                gestureOverlay?.isUserInteractionEnabled = false
                canvasView?.isUserInteractionEnabled = true
                canvasView?.drawingPolicy = .pencilOnly
                shapePreview?.isHidden = true
                selectionRect?.isHidden = true
                configureCanvasTool()
            }
            updateSelectionHighlight()
        }

        @MainActor func configureCanvasTool() {
            guard let canvasView, let vm = editorViewModel else { return }
            if vm.brushType == .eraser {
                canvasView.tool = PKEraserTool(.bitmap)
                canvasView.drawingPolicy = .anyInput
            } else if vm.brushType == .lasso {
                canvasView.tool = PKLassoTool()
                canvasView.drawingPolicy = .anyInput
            } else {
                let inkType: PKInkingTool.InkType
                switch vm.brushType {
                case .pencil:          inkType = .pencil
                case .marker:          inkType = .marker
                case .highlighterPen:  inkType = .marker
                case .brush:           inkType = .pen
                default:               inkType = .pen
                }
                let color = UIColor(vm.annotationColor)
                let width = vm.lineWidth * (inkType == .pencil ? 2 : 1)
                let alpha = vm.brushType == .highlighterPen ? CGFloat(0.4) : CGFloat(1.0)
                let ink = PKInkingTool(inkType, color: color.withAlphaComponent(alpha), width: width)
                canvasView.tool = ink
                canvasView.drawingPolicy = inkType == .pencil ? .pencilOnly : .anyInput
            }
        }

        @MainActor func updateSelectionHighlight() {
            guard let selRect = selectionRect, let pdfView, let vm = editorViewModel,
                  vm.gestureMode == .normal, let selected = vm.selectionManager.selectedAnnotation,
                  let page = selected.page, pdfView.currentPage === page else {
                selectionRect?.isHidden = true
                resizeHandle?.isHidden = true
                return
            }
            let pageBounds = selected.bounds
            let origin = pdfView.convert(pageBounds.origin, from: page)
            let size = CGSize(width: pageBounds.width * pdfView.scaleFactor,
                              height: pageBounds.height * pdfView.scaleFactor)
            let viewRect = CGRect(origin: origin, size: size).insetBy(dx: -4, dy: -4)
            selRect.path = UIBezierPath(rect: viewRect).cgPath
            selRect.isHidden = false

            // Resize handles for free-text annotations
            if selected.type == PDFAnnotationSubtype.freeText.rawValue, let handle = resizeHandle {
                let handleSize: CGFloat = 10
                var corners: [CGPoint] = []
                for dx in [0, 1] {
                    for dy in [0, 1] {
                        corners.append(CGPoint(x: viewRect.minX + CGFloat(dx) * viewRect.width - handleSize/2,
                                                y: viewRect.minY + CGFloat(dy) * viewRect.height - handleSize/2))
                    }
                }
                let handlePath = CGMutablePath()
                for corner in corners {
                    handlePath.addRect(CGRect(origin: corner, size: CGSize(width: handleSize, height: handleSize)))
                }
                handle.path = handlePath
                handle.isHidden = false
            } else {
                resizeHandle?.isHidden = true
            }
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView, let page = pdfView.currentPage, let index = pdfView.document?.index(for: page) else { return }
            currentPageIndex = index
            Task { @MainActor [weak self] in
                self?.editorViewModel?.selectionManager.deselectAll()
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let pdfView, let page = pdfView.currentPage else { return }
            let location = gesture.location(in: pdfView)
            let pagePoint = pdfView.convert(location, to: page)

            Task { @MainActor [weak self] in
                guard let self, let vm = editorViewModel else { return }
                if vm.gestureMode == .normal {
                    if let tappedAnnotation = annotation(at: pagePoint, on: page) {
                        vm.selectAnnotation(tappedAnnotation)
                    } else {
                        vm.selectionManager.deselectAll()
                    }
                    return
                }
                vm.handleTap(at: pagePoint, on: page)
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let pdfView, let page = pdfView.currentPage else { return }
            Task { @MainActor [weak self] in
                guard let vm = self?.editorViewModel, vm.annotationSubtool.isMultiPointTool && vm.editorMode == .annotate else { return }
                vm.completePolygon(on: page)
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let pdfView else { return }
            let location = gesture.location(in: pdfView)

            Task { @MainActor [weak self] in
                guard let self, let vm = editorViewModel else { return }
                if vm.gestureMode == .normal {
                    if checkResizeHandleDrag(gesture, pdfView: pdfView, location: location) { return }
                    handleAnnotationDrag(gesture, pdfView: pdfView, location: location)
                } else {
                    handleShapeDrawPan(gesture, pdfView: pdfView, location: location)
                }
            }
        }

        @MainActor private func checkResizeHandleDrag(_ gesture: UIPanGestureRecognizer, pdfView: PDFView, location: CGPoint) -> Bool {
            guard let handle = resizeHandle, let vm = editorViewModel, !handle.isHidden,
                  let page = pdfView.currentPage, let selected = vm.selectionManager.selectedAnnotation else { return false }

            let handleSize: CGFloat = 14
            let pageBounds = selected.bounds
            let origin = pdfView.convert(pageBounds.origin, from: page)
            let size = CGSize(width: pageBounds.width * pdfView.scaleFactor,
                              height: pageBounds.height * pdfView.scaleFactor)
            let viewRect = CGRect(origin: origin, size: size)
            let corners: [CGRect] = [
                CGRect(x: viewRect.minX - handleSize/2, y: viewRect.minY - handleSize/2, width: handleSize, height: handleSize),
                CGRect(x: viewRect.maxX - handleSize/2, y: viewRect.minY - handleSize/2, width: handleSize, height: handleSize),
                CGRect(x: viewRect.minX - handleSize/2, y: viewRect.maxY - handleSize/2, width: handleSize, height: handleSize),
                CGRect(x: viewRect.maxX - handleSize/2, y: viewRect.maxY - handleSize/2, width: handleSize, height: handleSize)
            ]

            switch gesture.state {
            case .began:
                for (i, corner) in corners.enumerated() {
                    if corner.contains(location) {
                        isResizing = true
                        resizeCorner = i
                        return true
                    }
                }
                return false
            case .changed:
                guard isResizing else { return false }
                let newBounds = selected.bounds
                let scale = pdfView.scaleFactor
                let deltaX = (location.x - corners[resizeCorner].midX) / scale
                let deltaY = (location.y - corners[resizeCorner].midY) / scale
                var updatedBounds = newBounds
                let minW: CGFloat = 40, minH: CGFloat = 14
                if resizeCorner == 1 || resizeCorner == 3 {
                    updatedBounds.size.width = max(minW, newBounds.width + deltaX)
                }
                if resizeCorner == 2 || resizeCorner == 3 {
                    updatedBounds.size.height = max(minH, newBounds.height + deltaY)
                }
                if resizeCorner == 0 || resizeCorner == 2 {
                    let newW = max(minW, newBounds.width - deltaX)
                    updatedBounds.origin.x = newBounds.maxX - newW
                    updatedBounds.size.width = newW
                }
                if resizeCorner == 0 || resizeCorner == 1 {
                    let newH = max(minH, newBounds.height - deltaY)
                    updatedBounds.origin.y = newBounds.maxY - newH
                    updatedBounds.size.height = newH
                }
                selected.bounds = updatedBounds
                updateSelectionHighlight()
                return true
            case .ended, .cancelled:
                isResizing = false
                if gesture.state == .ended { vm.storage.editCount += 1 }
                return true
            default:
                return false
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let pdfView, let page = pdfView.currentPage else { return }
            let location = gesture.location(in: pdfView)
            let pagePoint = pdfView.convert(location, to: page)

            Task { @MainActor [weak self] in
                guard let self, let vm = editorViewModel, let overlay = gestureOverlay else { return }
                guard let tappedAnnotation = annotation(at: pagePoint, on: page) else { return }
                vm.selectAnnotation(tappedAnnotation)

                let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                let weakVM = vm
                menu.addAction(UIAlertAction(title: "Edit Style", style: .default) { _ in
                    weakVM.showInspector = true
                })
                menu.addAction(UIAlertAction(title: "Duplicate", style: .default) { _ in
                    weakVM.duplicateSelectedAnnotation()
                })
                menu.addAction(UIAlertAction(title: tappedAnnotation.isReadOnly ? "Unlock" : "Lock", style: .default) { _ in
                    weakVM.toggleAnnotationLock(tappedAnnotation)
                })
                menu.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    if let page = tappedAnnotation.page {
                        weakVM.removeAnnotation(tappedAnnotation, from: page)
                    }
                })
                menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))

                if let windowScene = overlay.window?.windowScene,
                   let rootVC = windowScene.keyWindow?.rootViewController {
                    menu.popoverPresentationController?.sourceView = overlay
                    menu.popoverPresentationController?.sourceRect = CGRect(origin: location, size: .zero)
                    rootVC.present(menu, animated: true)
                }
            }
        }

        @MainActor private func handleAnnotationDrag(_ gesture: UIPanGestureRecognizer, pdfView: PDFView, location: CGPoint) {
            switch gesture.state {
            case .began:
                guard let page = pdfView.currentPage else { return }
                let pagePoint = pdfView.convert(location, to: page)
                if let ann = annotation(at: pagePoint, on: page) {
                    isDraggingAnnotation = true
                    dragAnnotation = ann
                    dragStartAnnotationBounds = ann.bounds
                    dragStartPoint = pagePoint
                    editorViewModel?.selectAnnotation(ann)
                }
            case .changed:
                guard isDraggingAnnotation, let ann = dragAnnotation,
                      let page = pdfView.currentPage, let startBounds = dragStartAnnotationBounds else { return }
                let pagePoint = pdfView.convert(location, to: page)
                let dx = pagePoint.x - dragStartPoint.x
                let dy = pagePoint.y - dragStartPoint.y
                ann.bounds = startBounds.offsetBy(dx: dx, dy: dy)
                updateSelectionHighlight()
            case .ended, .cancelled:
                isDraggingAnnotation = false
                dragAnnotation = nil
                dragStartAnnotationBounds = nil
                if gesture.state == .ended {
                    editorViewModel?.storage.editCount += 1
                }
            default:
                break
            }
        }

        @MainActor private func handleShapeDrawPan(_ gesture: UIPanGestureRecognizer, pdfView: PDFView, location: CGPoint) {
            guard let preview = shapePreview else { return }
            switch gesture.state {
            case .began:
                shapeStart = location
                preview.isHidden = false
            case .changed:
                let rect = normalizedRect(from: shapeStart, to: location)
                preview.path = UIBezierPath(rect: rect).cgPath
                if let vm = editorViewModel {
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
                editorViewModel?.handleShapeDrag(rect: rect, on: page)
            default:
                preview.isHidden = true
            }
        }

        private func annotation(at pagePoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
            let tolerance: CGFloat = 15
            for annotation in page.annotations {
                if annotation.isReadOnly { continue }
                var hitBounds = annotation.bounds
                if annotation.type == PDFAnnotationSubtype.text.rawValue || annotation.type == PDFAnnotationSubtype.freeText.rawValue {
                    hitBounds = hitBounds.insetBy(dx: -tolerance, dy: -tolerance)
                }
                if hitBounds.contains(pagePoint) {
                    return annotation
                }
            }
            return nil
        }

        private func normalizedRect(from: CGPoint, to: CGPoint) -> CGRect {
            CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
        }

        @MainActor private func bakeCanvasDrawing() {
            guard let canvasView, let pdfView, canvasView.drawing.bounds.isEmpty == false else { return }
            let drawing = canvasView.drawing
            canvasView.drawing = PKDrawing()

            let canvasToPage: (CGPoint) -> CGPoint = { [weak pdfView] point in
                guard let pdfView, let page = pdfView.currentPage else { return point }
                let inPDFView = canvasView.convert(point, to: pdfView)
                return pdfView.convert(inPDFView, to: page)
            }

            editorViewModel?.bakeDrawing(drawing, canvasToPageTransform: canvasToPage)
        }
    }
}

extension InteractivePDFKitView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer && other is UITapGestureRecognizer {
            return false
        }
        if gestureRecognizer is UILongPressGestureRecognizer {
            return false
        }
        if gestureRecognizer is UIPanGestureRecognizer && other is UIPanGestureRecognizer {
            return true
        }
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let vm = editorViewModel else { return true }
        if gestureRecognizer is UIPanGestureRecognizer && vm.gestureMode == .normal {
            guard let pdfView, let page = pdfView.currentPage else { return false }
            let location = gestureRecognizer.location(in: pdfView)
            let pagePoint = pdfView.convert(location, to: page)
            for annotation in page.annotations {
                if !annotation.isReadOnly && annotation.bounds.insetBy(dx: -10, dy: -10).contains(pagePoint) {
                    return true
                }
            }
            return false
        }
        return true
    }
}
