import PDFKit
import PencilKit
import SwiftUI

enum EditorMode: String, CaseIterable, Identifiable {
    case view      = "View"
    case annotate  = "Annotate"
    case draw      = "Draw"
    case text      = "Text"
    case stamp     = "Stamp"
    case signature = "Sign"
    case search    = "Search"
    case redact    = "Redact"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .view:      "eye"
        case .annotate:  "highlighter"
        case .draw:      "pencil.tip"
        case .text:      "character.textbox"
        case .stamp:     "seal"
        case .signature: "signature"
        case .search:    "magnifyingglass"
        case .redact:    "rectangle.slash"
        }
    }
}

enum AnnotationSubtool: String, CaseIterable, Identifiable {
    case highlight = "Highlight"
    case underline = "Underline"
    case strikeOut = "Strikeout"
    case squiggly  = "Squiggly"
    case note      = "Note"
    case rectangle = "Rectangle"
    case roundedRect = "Rounded Rect"
    case circle    = "Circle"
    case triangle  = "Triangle"
    case diamond   = "Diamond"
    case cloud     = "Cloud"
    case callout   = "Callout"
    case line      = "Line"
    case arrow     = "Arrow"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .highlight:    "highlighter"
        case .underline:    "underline"
        case .strikeOut:    "strikethrough"
        case .squiggly:     "character"
        case .note:         "note.text"
        case .rectangle:    "rectangle"
        case .roundedRect:  "rectangle.roundedtop"
        case .circle:       "circle"
        case .triangle:     "triangle"
        case .diamond:      "diamond"
        case .cloud:        "cloud"
        case .callout:      "text.bubble"
        case .line:         "line.diagonal"
        case .arrow:        "arrow.right"
        }
    }
    var isShapeTool: Bool {
        switch self {
        case .rectangle, .roundedRect, .circle, .triangle, .diamond, .cloud, .callout, .line, .arrow: true
        default: false
        }
    }
    var isMarkupTool: Bool { self == .highlight || self == .underline || self == .strikeOut || self == .squiggly }
    var pdfSubtype: PDFAnnotationSubtype {
        switch self {
        case .highlight:  .highlight
        case .underline:  .underline
        case .strikeOut:  .strikeOut
        case .squiggly:   .underline
        case .note:       .text
        case .rectangle, .roundedRect: .square
        case .circle:     .circle
        case .line, .arrow: .line
        default:          .square
        }
    }
}

struct StampDef: Identifiable {
    var id: String { label }
    let label: String
    let color: UIColor
    let isDynamic: Bool
    let imageData: Data?

    static let builtIn: [StampDef] = [
        .init(label: "APPROVED",     color: .systemGreen,  isDynamic: false, imageData: nil),
        .init(label: "REJECTED",     color: .systemRed,    isDynamic: false, imageData: nil),
        .init(label: "DRAFT",        color: .systemOrange, isDynamic: false, imageData: nil),
        .init(label: "CONFIDENTIAL", color: .systemRed,    isDynamic: false, imageData: nil),
        .init(label: "FINAL",        color: .systemPurple, isDynamic: false, imageData: nil),
        .init(label: "PAID",         color: .systemBlue,   isDynamic: false, imageData: nil),
        .init(label: "REVIEWED",     color: .systemTeal,   isDynamic: false, imageData: nil),
        .init(label: "VOID",         color: .systemGray,   isDynamic: false, imageData: nil),
        .init(label: "COMPLETED",    color: .systemGreen,  isDynamic: false, imageData: nil),
        .init(label: "URGENT",       color: .systemRed,    isDynamic: false, imageData: nil),
        .init(label: "EXPIRED",      color: .systemGray,   isDynamic: false, imageData: nil),
        .init(label: "COPY",         color: .systemOrange, isDynamic: false, imageData: nil),
        .init(label: "Date/Time",    color: .systemBlue,   isDynamic: true,  imageData: nil),
        .init(label: "Date Only",    color: .systemBlue,   isDynamic: true,  imageData: nil),
    ]

    var displayLabel: String {
        if isDynamic && label == "Date/Time" {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            return df.string(from: Date())
        }
        if isDynamic && label == "Date Only" {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }
        return label
    }
}

enum GestureMode {
    case normal
    case tapToPlace
    case shapeDraw
    case pencil
}

struct FreeTextStyle {
    var fontFamily: String = "Helvetica"
    var fontSize: CGFloat = 14
    var fontWeight: UIFont.Weight = .regular
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var textColor: Color = .black
    var backgroundColor: Color = .clear
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0
    var opacity: Double = 1.0
    var alignment: NSTextAlignment = .left
    var characterSpacing: CGFloat = 0
    var lineHeight: CGFloat = 1.2
}

@MainActor
final class PDFEditorViewModel: ObservableObject {
    @Published var editorMode: EditorMode = .view
    @Published var annotationSubtool: AnnotationSubtool = .highlight
    @Published var annotationColor: Color = .yellow
    @Published var annotationOpacity: Double = 0.6
    @Published var lineWidth: CGFloat = 2.5
    @Published var fontSize: CGFloat = 14
    @Published var fontColor: Color = .black
    @Published var fillColor: Color = .clear
    @Published var dashPattern: [CGFloat]?
    @Published var lineHeadStyle: PDFLineStyle = .closedArrow
    @Published var lineTailStyle: PDFLineStyle = .none

    @Published var searchText = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var searchResultIndex = 0

    @Published var showInspector = false
    @Published var showStampPicker = false
    @Published var showSearchPanel = false
    @Published var showSignatureSheet = false
    @Published var showTextInput = false
    @Published var textInputValue = ""

    @Published var showSidebar = false
    @Published var showNoteEditor = false
    @Published var noteToEdit: PDFAnnotation?
    @Published var freeTextStyle = FreeTextStyle()
    @Published var brushType: AnnotationTool = .pencil

    weak var pdfView: PDFView?

    var pendingTapPoint: (CGPoint, PDFPage)?
    var pendingStamp: StampDef?
    var pendingSignatureImage: UIImage?

    let storage = AnnotationStorage()
    let selectionManager = AnnotationSelectionManager()

    var canUndo: Bool { storage.undoManager.canUndo }
    var canRedo: Bool { storage.undoManager.canRedo }
    var editCount: Int { storage.editCount }

    var gestureMode: GestureMode {
        switch editorMode {
        case .view, .signature, .search: .normal
        case .draw: .pencil
        case .annotate where annotationSubtool.isShapeTool: .shapeDraw
        case .annotate: .normal
        case .redact: .shapeDraw
        default: .tapToPlace
        }
    }

    func addAnnotation(_ annotation: PDFAnnotation, to page: PDFPage) {
        storage.addAnnotation(annotation, to: page)
    }

    func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        storage.removeAnnotation(annotation, from: page)
        if selectionManager.selectedAnnotation === annotation {
            selectionManager.deselectAll()
        }
    }

    func undo() {
        storage.undoManager.undo()
    }

    func redo() {
        storage.undoManager.redo()
    }

    func applyMarkup(to selection: PDFSelection) {
        let color = UIColor(annotationColor).withAlphaComponent(annotationOpacity)
        for page in selection.pages {
            for line in selection.selectionsByLine() {
                let bounds = line.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: annotationSubtool.pdfSubtype, withProperties: nil)
                annotation.color = color
                addAnnotation(annotation, to: page)
            }
        }
    }

    func applyMarkupFromSelection() {
        guard let selection = pdfView?.currentSelection else { return }
        applyMarkup(to: selection)
    }

    func bakeDrawing(_ drawing: PKDrawing, canvasToPageTransform: (CGPoint) -> CGPoint) {
        guard let page = pdfView?.currentPage else { return }
        for stroke in drawing.strokes {
            let path = stroke.path
            guard path.count > 1 else { continue }
            let bezierPath = UIBezierPath()
            var first = true
            for i in 0..<path.count {
                let point = path[i]
                let pagePoint = canvasToPageTransform(point.location)
                if first {
                    bezierPath.move(to: pagePoint)
                    first = false
                } else {
                    bezierPath.addLine(to: pagePoint)
                }
            }
            let bounds = bezierPath.bounds.insetBy(dx: -4, dy: -4)
            guard bounds.width > 1, bounds.height > 1 else { continue }
            let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annotation.add(bezierPath)
            annotation.color = stroke.ink.color
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            addAnnotation(annotation, to: page)
        }
    }

    func handleTap(at pagePoint: CGPoint, on page: PDFPage) {
        switch editorMode {
        case .text:
            pendingTapPoint = (pagePoint, page)
            textInputValue = ""
            showTextInput = true
        case .stamp:
            if let stamp = pendingStamp {
                placeStamp(stamp, at: pagePoint, on: page)
            } else {
                pendingTapPoint = (pagePoint, page)
                showStampPicker = true
            }
        case .annotate where annotationSubtool == .note:
            placeStickyNote(at: pagePoint, on: page)
        case .signature:
            placeSignatureStamp(at: pagePoint, on: page)
        default:
            break
        }
    }

    func handleShapeDrag(rect: CGRect, on page: PDFPage) {
        guard rect.width > 4, rect.height > 4 else { return }
        let color = UIColor(annotationColor).withAlphaComponent(annotationOpacity)

        if editorMode == .redact {
            let annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
            annotation.color = .black
            annotation.interiorColor = .black
            annotation.contents = "__REDACT__"
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            addAnnotation(annotation, to: page)
            return
        }

        if annotationSubtool == .arrow || annotationSubtool == .line {
            let annotation = PDFAnnotation(bounds: rect.insetBy(dx: -lineWidth, dy: -lineWidth), forType: .line, withProperties: nil)
            annotation.startPoint = CGPoint(x: rect.minX + lineWidth, y: rect.midY)
            annotation.endPoint = CGPoint(x: rect.maxX - lineWidth, y: rect.midY)
            let border = PDFBorder()
            border.lineWidth = lineWidth
            border.dashPattern = dashPattern as? [NSNumber]
            annotation.border = border
            annotation.color = color
            annotation.startLineStyle = annotationSubtool == .arrow ? .closedArrow : lineTailStyle
            annotation.endLineStyle = annotationSubtool == .arrow ? lineHeadStyle : lineHeadStyle
            annotation.interiorColor = color.withAlphaComponent(0.5)

            if annotationSubtool == .arrow {
                let length = hypot(rect.width, rect.height)
                let measureText = "\(Int(length / 2)) pt"
                let measureAnnotation = PDFAnnotation(bounds: CGRect(x: rect.midX - 40, y: rect.minY - 18, width: 80, height: 14), forType: .freeText, withProperties: nil)
                measureAnnotation.contents = measureText
                measureAnnotation.font = UIFont.systemFont(ofSize: 9)
                measureAnnotation.fontColor = UIColor.secondaryLabel
                measureAnnotation.color = .clear
                measureAnnotation.alignment = .center
                measureAnnotation.isReadOnly = true
                addAnnotation(measureAnnotation, to: page)
            }

            addAnnotation(annotation, to: page)
            return
        }

        if annotationSubtool == .rectangle || annotationSubtool == .circle {
            let annotation = PDFAnnotation(bounds: rect, forType: annotationSubtool.pdfSubtype, withProperties: nil)
            let border = PDFBorder()
            border.lineWidth = lineWidth
            border.dashPattern = dashPattern as? [NSNumber]
            annotation.border = border
            annotation.color = color
            annotation.interiorColor = fillColor == .clear
                ? color.withAlphaComponent(annotationOpacity * 0.15)
                : UIColor(fillColor).withAlphaComponent(annotationOpacity * 0.3)
            addAnnotation(annotation, to: page)
            return
        }

        let bezierPath: UIBezierPath
        switch annotationSubtool {
        case .roundedRect:
            bezierPath = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        case .triangle:
            bezierPath = UIBezierPath()
            bezierPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
            bezierPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            bezierPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            bezierPath.close()
        case .diamond:
            bezierPath = UIBezierPath()
            bezierPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
            bezierPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            bezierPath.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            bezierPath.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            bezierPath.close()
        case .cloud:
            bezierPath = cloudPath(in: rect)
        case .callout:
            bezierPath = calloutPath(in: rect)
        default:
            bezierPath = UIBezierPath(rect: rect)
        }

        let inkAnnotation = PDFAnnotation(bounds: rect.insetBy(dx: -lineWidth - 2, dy: -lineWidth - 2), forType: .ink, withProperties: nil)
        let border = PDFBorder()
        border.lineWidth = 0
        inkAnnotation.border = border
        let inset: CGFloat = lineWidth + 2
        let offsetPath = UIBezierPath()
        offsetPath.move(to: CGPoint(x: bezierPath.bounds.minX - rect.minX + (rect.minX - inset),
                                     y: bezierPath.bounds.minY - rect.minY + (rect.minY - inset)))
        bezierPath.cgPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                offsetPath.move(to: CGPoint(x: points[0].x - rect.minX + (rect.minX - inset),
                                             y: points[0].y - rect.minY + (rect.minY - inset)))
            case .addLineToPoint:
                offsetPath.addLine(to: CGPoint(x: points[0].x - rect.minX + (rect.minX - inset),
                                                y: points[0].y - rect.minY + (rect.minY - inset)))
            case .addQuadCurveToPoint:
                offsetPath.addQuadCurve(to: CGPoint(x: points[1].x - rect.minX + (rect.minX - inset),
                                                     y: points[1].y - rect.minY + (rect.minY - inset)),
                                         controlPoint: CGPoint(x: points[0].x - rect.minX + (rect.minX - inset),
                                                                y: points[0].y - rect.minY + (rect.minY - inset)))
            case .addCurveToPoint:
                offsetPath.addCurve(to: CGPoint(x: points[2].x - rect.minX + (rect.minX - inset),
                                                 y: points[2].y - rect.minY + (rect.minY - inset)),
                                     controlPoint1: CGPoint(x: points[0].x - rect.minX + (rect.minX - inset),
                                                             y: points[0].y - rect.minY + (rect.minY - inset)),
                                     controlPoint2: CGPoint(x: points[1].x - rect.minX + (rect.minX - inset),
                                                             y: points[1].y - rect.minY + (rect.minY - inset)))
            case .closeSubpath:
                offsetPath.close()
            @unknown default: break
            }
        }
        inkAnnotation.add(offsetPath)
        inkAnnotation.color = color
        addAnnotation(inkAnnotation, to: page)
    }

    private func cloudPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let arcs = 8
        let arcRadius = min(rect.width, rect.height) / CGFloat(arcs)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arcRadius))
        for i in 0..<arcs * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(arcs)
            let cx = rect.minX + rect.width * 0.5 + cos(angle) * rect.width * 0.4
            let cy = rect.minY + rect.height * 0.5 + sin(angle) * rect.height * 0.4
            path.addArc(withCenter: CGPoint(x: cx, y: cy), radius: arcRadius, startAngle: angle, endAngle: angle + .pi / CGFloat(arcs), clockwise: true)
        }
        path.close()
        return path
    }

    private func calloutPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        let tailWidth: CGFloat = 12
        let tailHeight: CGFloat = 16
        let tailX = rect.minX + rect.width * 0.2
        path.move(to: CGPoint(x: tailX, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailX + tailWidth / 2, y: rect.maxY + tailHeight))
        path.addLine(to: CGPoint(x: tailX + tailWidth, y: rect.maxY))
        path.close()
        return path
    }

    func confirmTextAnnotation() {
        guard let (point, page) = pendingTapPoint, !textInputValue.isEmpty else { pendingTapPoint = nil; return }
        pendingTapPoint = nil
        let style = freeTextStyle
        let charWidth = style.fontSize * 0.65
        let width = max(120, CGFloat(textInputValue.count) * charWidth + 24)
        let height = style.fontSize * 2.8 * style.lineHeight
        let rect = CGRect(x: point.x - width / 2, y: point.y - height * 0.3, width: width, height: height)
        let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        annotation.contents = textInputValue
        let font: UIFont
        if style.isBold && style.isItalic {
            font = UIFont(descriptor: UIFontDescriptor(name: style.fontFamily, size: style.fontSize).withSymbolicTraits([.traitBold, .traitItalic]) ?? UIFontDescriptor(), size: style.fontSize)
        } else if style.isBold {
            font = UIFont.boldSystemFont(ofSize: style.fontSize)
        } else if style.isItalic {
            font = UIFont.italicSystemFont(ofSize: style.fontSize)
        } else {
            font = UIFont(name: style.fontFamily, size: style.fontSize) ?? .systemFont(ofSize: style.fontSize)
        }
        annotation.font = font
        annotation.fontColor = UIColor(style.textColor)
        annotation.color = style.backgroundColor == .clear ? .clear : UIColor(style.backgroundColor)
        annotation.alignment = style.alignment
        if style.borderWidth > 0 && style.borderColor != .clear {
            let border = PDFBorder()
            border.lineWidth = style.borderWidth
            annotation.border = border
            annotation.color = UIColor(style.borderColor)
        } else {
            let border = PDFBorder(); border.lineWidth = 0
            annotation.border = border
        }
        addAnnotation(annotation, to: page)
    }

    func placeStickyNote(at point: CGPoint, on page: PDFPage) {
        let size: CGFloat = 30
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        let annotation = PDFAnnotation(bounds: rect, forType: .text, withProperties: nil)
        annotation.contents = ""
        annotation.color = UIColor(annotationColor)
        annotation.userName = UIDevice.current.name
        annotation.modificationDate = Date()
        addAnnotation(annotation, to: page)
    }

    func placeSignatureStamp(at point: CGPoint, on page: PDFPage) {
        if pendingSignatureImage != nil {
            let imageRect = CGRect(x: point.x - 75, y: point.y - 25, width: 150, height: 50)
            let annotation = PDFAnnotation(bounds: imageRect, forType: .stamp, withProperties: nil)
            annotation.contents = "Signature"
            annotation.color = UIColor(annotationColor).withAlphaComponent(0.15)
            annotation.userName = UIDevice.current.name
            annotation.modificationDate = Date()
            addAnnotation(annotation, to: page)
            pendingSignatureImage = nil
        } else {
            let rect = CGRect(x: point.x - 55, y: point.y - 20, width: 110, height: 40)
            let annotation = PDFAnnotation(bounds: rect, forType: .stamp, withProperties: nil)
            annotation.contents = "Signature"
            annotation.color = UIColor(annotationColor).withAlphaComponent(0.15)
            annotation.userName = UIDevice.current.name
            annotation.modificationDate = Date()
            addAnnotation(annotation, to: page)
        }
    }

    func placeStamp(_ stamp: StampDef, at point: CGPoint, on page: PDFPage) {
        let label = stamp.displayLabel
        let charWidth: CGFloat = 9
        let width = max(120, CGFloat(label.count) * charWidth + 24)
        let height: CGFloat = stamp.imageData != nil ? 60 : 40
        let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)

        let annotation = PDFAnnotation(bounds: rect, forType: .stamp, withProperties: nil)
        annotation.contents = label
        annotation.color = stamp.color.withAlphaComponent(0.18)
        let border = PDFBorder()
        border.lineWidth = 1.5
        annotation.border = border
        annotation.font = UIFont.boldSystemFont(ofSize: 14)
        annotation.fontColor = stamp.color
        addAnnotation(annotation, to: page)
        pendingStamp = nil
    }

    func placeStampAtPendingPoint(_ stamp: StampDef) {
        guard let (point, page) = pendingTapPoint else { pendingStamp = stamp; return }
        pendingTapPoint = nil
        placeStamp(stamp, at: point, on: page)
    }

    func performSearch(in document: PDFDocument) {
        guard !searchText.isEmpty else { searchResults = []; return }
        searchResults = document.findString(searchText, withOptions: [.caseInsensitive])
        searchResultIndex = 0
    }

    func nextResult() {
        guard !searchResults.isEmpty else { return }
        searchResultIndex = (searchResultIndex + 1) % searchResults.count
    }

    func previousResult() {
        guard !searchResults.isEmpty else { return }
        searchResultIndex = (searchResultIndex - 1 + searchResults.count) % searchResults.count
    }

    var currentSearchResult: PDFSelection? {
        guard searchResults.indices.contains(searchResultIndex) else { return nil }
        return searchResults[searchResultIndex]
    }

    func applyRedactions(to document: PDFDocument?) {
        guard let document else { return }
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let redactions = page.annotations.filter { $0.contents == "__REDACT__" }
            for redact in redactions {
                page.removeAnnotation(redact)
                let annotation = PDFAnnotation(bounds: redact.bounds, forType: .square, withProperties: nil)
                annotation.color = .black
                annotation.interiorColor = .black
                let border = PDFBorder()
                border.lineWidth = 0
                annotation.border = border
                annotation.contents = "[Redacted]"
                annotation.isReadOnly = true
                annotation.shouldDisplay = true
                annotation.shouldPrint = true
                page.addAnnotation(annotation)
            }
        }
        storage.editCount += 1
    }

    func selectAnnotation(_ annotation: PDFAnnotation) {
        selectionManager.select(annotation)
        if annotation.type == PDFAnnotationSubtype.text.rawValue {
            noteToEdit = annotation
            showNoteEditor = true
        } else {
            showInspector = true
        }
    }

    func allAnnotations() -> [(PDFAnnotation, Int)] {
        guard let document = pdfView?.document else { return [] }
        return storage.allAnnotations(in: document)
    }
}
