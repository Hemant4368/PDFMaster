import PDFKit
import SwiftUI

struct AnnotationUndoAction {
    enum Kind { case add, remove, modify }
    let kind: Kind
    let annotation: PDFAnnotation
    let page: PDFPage
    var previousProperties: [String: Any]?
    let timestamp: Date
}

@MainActor
final class AnnotationUndoManager: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var history: [AnnotationUndoAction] = []

    private var undoStack: [AnnotationUndoAction] = []
    private var redoStack: [AnnotationUndoAction] = []
    private let maxHistory = 200

    var didChange: (() -> Void)?

    func recordAdd(_ annotation: PDFAnnotation, on page: PDFPage) {
        let action = AnnotationUndoAction(
            kind: .add, annotation: annotation, page: page,
            previousProperties: nil, timestamp: Date()
        )
        undoStack.append(action)
        redoStack.removeAll()
        updateState()
    }

    func recordRemove(_ annotation: PDFAnnotation, from page: PDFPage) {
        let props = captureProperties(annotation)
        let action = AnnotationUndoAction(
            kind: .remove, annotation: annotation, page: page,
            previousProperties: props, timestamp: Date()
        )
        undoStack.append(action)
        redoStack.removeAll()
        updateState()
    }

    func recordModify(_ annotation: PDFAnnotation, on page: PDFPage, previousProperties: [String: Any]) {
        let action = AnnotationUndoAction(
            kind: .modify, annotation: annotation, page: page,
            previousProperties: previousProperties, timestamp: Date()
        )
        undoStack.append(action)
        redoStack.removeAll()
        updateState()
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action.kind {
        case .add:
            action.page.removeAnnotation(action.annotation)
        case .remove:
            if let props = action.previousProperties {
                restoreProperties(action.annotation, props: props)
            }
            action.page.addAnnotation(action.annotation)
        case .modify:
            if let props = action.previousProperties {
                let current = captureProperties(action.annotation)
                restoreProperties(action.annotation, props: props)
                let revertAction = AnnotationUndoAction(
                    kind: .modify, annotation: action.annotation, page: action.page,
                    previousProperties: current, timestamp: Date()
                )
                redoStack.append(revertAction)
            }
        }
        if action.kind != .modify {
            redoStack.append(action)
        }
        updateState()
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        switch action.kind {
        case .add:
            action.page.addAnnotation(action.annotation)
        case .remove:
            action.page.removeAnnotation(action.annotation)
        case .modify:
            if let props = action.previousProperties {
                let current = captureProperties(action.annotation)
                restoreProperties(action.annotation, props: props)
                let revertAction = AnnotationUndoAction(
                    kind: .modify, annotation: action.annotation, page: action.page,
                    previousProperties: current, timestamp: Date()
                )
                undoStack.append(revertAction)
            }
        }
        if action.kind != .modify {
            undoStack.append(action)
        }
        updateState()
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        history.removeAll()
        updateState()
    }

    private func updateState() {
        while undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        history = Array((undoStack + redoStack).suffix(50))
        didChange?()
    }

    private func captureProperties(_ annotation: PDFAnnotation) -> [String: Any] {
        var props: [String: Any] = [:]
        props["bounds"] = NSCoder.string(for: annotation.bounds)
        props["color"] = annotation.color
        props["contents"] = annotation.contents
        if let border = annotation.border {
            props["borderWidth"] = border.lineWidth
            props["borderStyle"] = border.style.rawValue
        }
        props["fontColor"] = annotation.fontColor
        props["fontName"] = annotation.font?.fontName
        props["fontSize"] = annotation.font?.pointSize
        return props
    }

    private func restoreProperties(_ annotation: PDFAnnotation, props: [String: Any]) {
        if let boundsStr = props["bounds"] as? String {
            annotation.bounds = NSCoder.cgRect(for: boundsStr)
        }
        if let color = props["color"] as? UIColor {
            annotation.color = color
        }
        if let contents = props["contents"] as? String {
            annotation.contents = contents
        }
        if let bw = props["borderWidth"] as? CGFloat {
            let border = PDFBorder()
            border.lineWidth = bw
            if let styleRaw = props["borderStyle"] as? Int,
               let style = PDFBorderStyle(rawValue: styleRaw) {
                border.style = style
            }
            annotation.border = border
        }
        if let fc = props["fontColor"] as? UIColor {
            annotation.fontColor = fc
        }
        if let fn = props["fontName"] as? String, let fs = props["fontSize"] as? CGFloat {
            annotation.font = UIFont(name: fn, size: fs)
        }
    }
}
