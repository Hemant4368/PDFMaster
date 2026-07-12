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

struct AnnotationUndoGroup {
    let actions: [AnnotationUndoAction]
    let timestamp: Date
}

enum UndoableItem {
    case single(AnnotationUndoAction)
    case group(AnnotationUndoGroup)
}

@MainActor
final class AnnotationUndoManager: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var history: [AnnotationUndoAction] = []

    private var undoStack: [UndoableItem] = []
    private var redoStack: [UndoableItem] = []
    private let maxHistory = 200

    var didChange: (() -> Void)?

    func recordAdd(_ annotation: PDFAnnotation, on page: PDFPage) {
        let action = AnnotationUndoAction(
            kind: .add, annotation: annotation, page: page,
            previousProperties: nil, timestamp: Date()
        )
        undoStack.append(.single(action))
        redoStack.removeAll()
        updateState()
    }

    func recordRemove(_ annotation: PDFAnnotation, from page: PDFPage) {
        let props = captureProperties(annotation)
        let action = AnnotationUndoAction(
            kind: .remove, annotation: annotation, page: page,
            previousProperties: props, timestamp: Date()
        )
        undoStack.append(.single(action))
        redoStack.removeAll()
        updateState()
    }

    func recordModify(_ annotation: PDFAnnotation, on page: PDFPage, previousProperties: [String: Any]) {
        let action = AnnotationUndoAction(
            kind: .modify, annotation: annotation, page: page,
            previousProperties: previousProperties, timestamp: Date()
        )
        undoStack.append(.single(action))
        redoStack.removeAll()
        updateState()
    }

    func recordBatch(_ actions: [AnnotationUndoAction]) {
        guard !actions.isEmpty else { return }
        undoStack.append(.group(AnnotationUndoGroup(actions: actions, timestamp: Date())))
        redoStack.removeAll()
        updateState()
    }

    // Reverses a recorded action (for undo). Pushes the original action to the redo stack so redo can re-apply it forward.
    private func applyForUndo(_ action: AnnotationUndoAction) -> AnnotationUndoAction? {
        switch action.kind {
        case .add:
            action.page.removeAnnotation(action.annotation)
            return action  // redo will re-add
        case .remove:
            if let props = action.previousProperties {
                restoreProperties(action.annotation, props: props)
            }
            action.page.addAnnotation(action.annotation)
            return action  // redo will re-remove
        case .modify:
            guard let props = action.previousProperties else { return nil }
            let current = captureProperties(action.annotation)
            restoreProperties(action.annotation, props: props)
            return AnnotationUndoAction(
                kind: .modify, annotation: action.annotation, page: action.page,
                previousProperties: current, timestamp: Date()
            )
        }
    }

    // Re-applies a recorded action forward (for redo). Pushes the original action to the undo stack so undo can reverse it again.
    private func applyForRedo(_ action: AnnotationUndoAction) -> AnnotationUndoAction? {
        switch action.kind {
        case .add:
            action.page.addAnnotation(action.annotation)
            return action  // undo will re-remove
        case .remove:
            let props = captureProperties(action.annotation)
            action.page.removeAnnotation(action.annotation)
            return AnnotationUndoAction(
                kind: .remove, annotation: action.annotation, page: action.page,
                previousProperties: props, timestamp: Date()
            )
        case .modify:
            guard let props = action.previousProperties else { return nil }
            let current = captureProperties(action.annotation)
            restoreProperties(action.annotation, props: props)
            return AnnotationUndoAction(
                kind: .modify, annotation: action.annotation, page: action.page,
                previousProperties: current, timestamp: Date()
            )
        }
    }

    func undo() {
        guard let item = undoStack.popLast() else { return }
        switch item {
        case .single(let action):
            if let redoAction = applyForUndo(action) {
                redoStack.append(.single(redoAction))
            }
        case .group(let group):
            var redoActions: [AnnotationUndoAction] = []
            for action in group.actions.reversed() {
                if let redoAction = applyForUndo(action) {
                    redoActions.append(redoAction)
                }
            }
            if !redoActions.isEmpty {
                redoStack.append(.group(AnnotationUndoGroup(actions: redoActions, timestamp: Date())))
            }
        }
        updateState()
    }

    func redo() {
        guard let item = redoStack.popLast() else { return }
        switch item {
        case .single(let action):
            if let undoAction = applyForRedo(action) {
                undoStack.append(.single(undoAction))
            }
        case .group(let group):
            var undoActions: [AnnotationUndoAction] = []
            for action in group.actions.reversed() {
                if let undoAction = applyForRedo(action) {
                    undoActions.append(undoAction)
                }
            }
            if !undoActions.isEmpty {
                undoStack.append(.group(AnnotationUndoGroup(actions: undoActions, timestamp: Date())))
            }
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
        history = Array((undoStack + redoStack).compactMap { item -> AnnotationUndoAction? in
            switch item { case .single(let a): return a; case .group: return nil }
        }.suffix(50))
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
