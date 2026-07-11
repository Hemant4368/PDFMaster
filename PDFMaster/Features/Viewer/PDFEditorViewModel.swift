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
    case circle    = "Circle"
    case line      = "Line"
    case arrow     = "Arrow"
    case polyline  = "Polyline"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .highlight:  "highlighter"
        case .underline:  "underline"
        case .strikeOut:  "strikethrough"
        case .squiggly:   "character"
        case .note:       "note.text"
        case .rectangle:  "rectangle"
        case .circle:     "circle"
        case .line:       "line.diagonal"
        case .arrow:      "arrow.right"
        case .polyline:   "line.diagonal"
        }
    }
    var isShapeTool: Bool { self == .rectangle || self == .circle || self == .line || self == .arrow }
    var isMarkupTool: Bool { self == .highlight || self == .underline || self == .strikeOut || self == .squiggly }
    var pdfSubtype: PDFAnnotationSubtype {
        switch self {
        case .highlight:  .highlight
        case .underline:  .underline
        case .strikeOut:  .strikeOut
        case .squiggly:   .underline
        case .note:       .text
        case .rectangle:  .square
        case .circle:     .circle
        case .line, .arrow: .line
        case .polyline:   .line
        }
    }
}

struct StampDef: Identifiable {
    var id: String { label }
    let label: String
    let color: UIColor
    static let builtIn: [StampDef] = [
        .init(label: "APPROVED",     color: .systemGreen),
        .init(label: "REJECTED",     color: .systemRed),
        .init(label: "DRAFT",        color: .systemOrange),
        .init(label: "CONFIDENTIAL", color: .systemRed),
        .init(label: "FINAL",        color: .systemPurple),
        .init(label: "PAID",         color: .systemBlue),
        .init(label: "REVIEWED",     color: .systemTeal),
        .init(label: "VOID",         color: .systemGray),
        .init(label: "COMPLETED",    color: .systemGreen),
        .init(label: "URGENT",       color: .systemRed),
        .init(label: "EXPIRED",      color: .systemGray),
        .init(label: "COPY",         color: .systemOrange),
    ]
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
    @Published var freeTextStyle = FreeTextStyle()
    @Published var brushType: AnnotationTool = .pencil

    weak var pdfView: PDFView?

    var pendingTapPoint: (CGPoint, PDFPage)?
    var pendingStamp: StampDef?

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
        let annotation = PDFAnnotation(bounds: rect, forType: annotationSubtool.pdfSubtype, withProperties: nil)
        let border = PDFBorder()
        border.lineWidth = lineWidth
        border.dashPattern = dashPattern as? [NSNumber]
        annotation.border = border
        annotation.color = UIColor(annotationColor).withAlphaComponent(annotationOpacity)

        let hasFill: Bool
        switch annotationSubtool {
        case .rectangle, .circle: hasFill = true
        default: hasFill = false
        }
        if hasFill {
            annotation.interiorColor = fillColor == .clear
                ? UIColor(annotationColor).withAlphaComponent(annotationOpacity * 0.15)
                : UIColor(fillColor).withAlphaComponent(annotationOpacity * 0.3)
        }

        if annotationSubtool == .arrow {
            annotation.type = "Line"
            let startX = rect.origin.x + rect.width * 0.1
            let startY = rect.midY
            let endX = rect.maxX - rect.width * 0.1
            let endY = rect.midY
            annotation.bounds = CGRect(x: startX, y: startY - lineWidth, width: endX - startX, height: lineWidth * 2)
        }

        addAnnotation(annotation, to: page)
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
        let rect = CGRect(x: point.x - 55, y: point.y - 20, width: 110, height: 40)
        let annotation = PDFAnnotation(bounds: rect, forType: .stamp, withProperties: nil)
        annotation.contents = "Signature"
        annotation.color = UIColor(annotationColor).withAlphaComponent(0.15)
        annotation.userName = UIDevice.current.name
        addAnnotation(annotation, to: page)
    }

    func placeStamp(_ stamp: StampDef, at point: CGPoint, on page: PDFPage) {
        let rect = CGRect(x: point.x - 60, y: point.y - 20, width: 120, height: 40)
        let annotation = PDFAnnotation(bounds: rect, forType: .stamp, withProperties: nil)
        annotation.contents = stamp.label
        annotation.color = stamp.color.withAlphaComponent(0.18)
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

    func selectAnnotation(_ annotation: PDFAnnotation) {
        selectionManager.select(annotation)
        showInspector = true
    }

    func allAnnotations() -> [(PDFAnnotation, Int)] {
        guard let document = pdfView?.document else { return [] }
        return storage.allAnnotations(in: document)
    }
}
