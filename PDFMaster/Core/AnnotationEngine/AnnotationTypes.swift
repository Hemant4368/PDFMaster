import PDFKit
import SwiftUI

typealias AnnotationID = UUID

struct AnnotationAuthor: Codable, Equatable {
    var name: String
    var email: String?
}

enum AnnotationFlags: UInt {
    case invisible    = 1
    case hidden       = 2
    case print        = 4
    case noZoom       = 8
    case noRotate     = 16
    case noView       = 32
    case readOnly     = 64
    case locked       = 128
    case toggleNoView = 256
    case lockedContents = 512
}

struct AnnotationComment: Identifiable, Codable {
    var id: AnnotationID
    var author: AnnotationAuthor
    var text: String
    var date: Date
    var replies: [AnnotationComment]
}

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case highlight
    case underline
    case strikethrough
    case squiggly
    case note
    case freeText
    case pencil
    case marker
    case highlighterPen
    case brush
    case eraser
    case lasso
    case rectangle
    case roundedRect
    case circle
    case ellipse
    case triangle
    case polygon
    case diamond
    case cloud
    case arrow
    case doubleArrow
    case line
    case polyline
    case measurement
    case callout
    case speechBubble
    case stamp
    case signature
    case image
    case link
    case fileAttachment
    case redact

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select:        "cursorarrow"
        case .highlight:     "highlighter"
        case .underline:     "underline"
        case .strikethrough: "strikethrough"
        case .squiggly:      "character"
        case .note:          "note.text"
        case .freeText:      "character.textbox"
        case .pencil:        "pencil.tip"
        case .marker:        "pencil.tip"
        case .highlighterPen:"highlighter"
        case .brush:         "paintbrush.pointed"
        case .eraser:        "eraser"
        case .lasso:         "lasso"
        case .rectangle:     "rectangle"
        case .roundedRect:   "rectangle.roundedtop"
        case .circle:        "circle"
        case .ellipse:       "oval"
        case .triangle:      "triangle"
        case .polygon:       "polygon"
        case .diamond:       "diamond"
        case .cloud:         "cloud"
        case .arrow:         "arrow.right"
        case .doubleArrow:   "arrow.left.and.right"
        case .line:          "line.diagonal"
        case .polyline:      "line.diagonal"
        case .measurement:   "ruler"
        case .callout:       "text.bubble"
        case .speechBubble:  "speech.bubble"
        case .stamp:         "seal"
        case .signature:     "signature"
        case .image:         "photo"
        case .link:          "link"
        case .fileAttachment:"paperclip"
        case .redact:        "rectangle.slash"
        }
    }

    var isMarkup: Bool {
        switch self {
        case .highlight, .underline, .strikethrough, .squiggly: true
        default: false
        }
    }

    var isShape: Bool {
        switch self {
        case .rectangle, .roundedRect, .circle, .ellipse, .triangle,
             .polygon, .diamond, .cloud, .callout, .speechBubble: true
        default: false
        }
    }

    var isLine: Bool {
        switch self {
        case .arrow, .doubleArrow, .line, .polyline, .measurement: true
        default: false
        }
    }

    var pdfSubtype: PDFAnnotationSubtype? {
        switch self {
        case .highlight:          .highlight
        case .underline:          .underline
        case .strikethrough:      .strikeOut
        case .note:               .text
        case .freeText:           .freeText
        case .rectangle:          .square
        case .roundedRect:        .square
        case .circle, .ellipse:   .circle
        case .line, .arrow, .doubleArrow, .polyline, .measurement: .line
        case .stamp, .signature:  .stamp
        case .image:              .stamp
        case .fileAttachment:     .fileAttachment
        case .link:               .link
        case .squiggly:           .underline
        default:                  nil
        }
    }
}

enum LineHeadStyle: String, CaseIterable {
    case none     = "None"
    case open     = "Open Arrow"
    case filled   = "Filled Arrow"
    case circle   = "Circle"
    case square   = "Square"
    case diamond  = "Diamond"
}

struct AnnotationStyle: Equatable {
    var color: Color = .yellow
    var opacity: Double = 0.6
    var lineWidth: CGFloat = 2
    var fillColor: Color = .clear
    var dashPattern: [CGFloat]?
    var lineHead: LineHeadStyle = .none
    var lineTail: LineHeadStyle = .none

    var uiColor: UIColor { UIColor(color).withAlphaComponent(opacity) }
    var uiFillColor: UIColor { UIColor(fillColor).withAlphaComponent(opacity * 0.2) }
}

extension PDFAnnotationSubtype {
    static let ink = PDFAnnotationSubtype(rawValue: "/Ink")
    static let stamp = PDFAnnotationSubtype(rawValue: "/Stamp")
    static let widget = PDFAnnotationSubtype(rawValue: "/Widget")
    static let popup = PDFAnnotationSubtype(rawValue: "/Popup")
    static let fileAttachment = PDFAnnotationSubtype(rawValue: "/FileAttachment")
    static let link = PDFAnnotationSubtype(rawValue: "/Link")
    static let redact = PDFAnnotationSubtype(rawValue: "/Redact")
}

extension PDFAnnotation {
    var annotationID: AnnotationID {
        if let existing = value(forAnnotationKey: .UUID) as? String,
           let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let id = AnnotationID()
        setValue(id.uuidString, forAnnotationKey: .UUID)
        return id
    }

    var authorName: String {
        get { userName ?? "" }
        set { userName = newValue }
    }

    var creationDate: Date {
        get { modificationDate ?? Date() }
        set { modificationDate = newValue }
    }
}

extension PDFAnnotationKey {
    static let UUID = PDFAnnotationKey(rawValue: "UUID")
    static let imageData = PDFAnnotationKey(rawValue: "ImageData")
}
