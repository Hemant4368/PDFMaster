import PDFKit
import SwiftUI

@MainActor
final class AnnotationStorage: ObservableObject {
    @Published private(set) var annotationCount = 0
    @Published var editCount = 0

    let undoManager = AnnotationUndoManager()

    func addAnnotation(_ annotation: PDFAnnotation, to page: PDFPage) {
        page.addAnnotation(annotation)
        undoManager.recordAdd(annotation, on: page)
        annotationCount += 1
        editCount += 1
    }

    func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        undoManager.recordRemove(annotation, from: page)
        page.removeAnnotation(annotation)
        annotationCount = max(0, annotationCount - 1)
        editCount += 1
    }

    func modifyAnnotation(_ annotation: PDFAnnotation, on page: PDFPage, previousProperties: [String: Any]) {
        undoManager.recordModify(annotation, on: page, previousProperties: previousProperties)
        editCount += 1
    }

    func addAnnotations(_ annotations: [(PDFAnnotation, PDFPage)]) {
        var actions: [AnnotationUndoAction] = []
        for (annotation, page) in annotations {
            page.addAnnotation(annotation)
            actions.append(AnnotationUndoAction(
                kind: .add, annotation: annotation, page: page,
                previousProperties: nil, timestamp: Date()
            ))
        }
        undoManager.recordBatch(actions)
        annotationCount += annotations.count
        editCount += 1
    }

    func removeAnnotations(_ annotations: [(PDFAnnotation, PDFPage)]) {
        var actions: [AnnotationUndoAction] = []
        for (annotation, page) in annotations {
            let props = capturePropertiesForBatch(annotation)
            actions.append(AnnotationUndoAction(
                kind: .remove, annotation: annotation, page: page,
                previousProperties: props, timestamp: Date()
            ))
            page.removeAnnotation(annotation)
        }
        undoManager.recordBatch(actions)
        annotationCount = max(0, annotationCount - annotations.count)
        editCount += 1
    }

    private func capturePropertiesForBatch(_ annotation: PDFAnnotation) -> [String: Any] {
        var props: [String: Any] = [:]
        props["bounds"] = NSCoder.string(for: annotation.bounds)
        props["color"] = annotation.color
        props["contents"] = annotation.contents
        return props
    }

    func allAnnotations(in document: PDFDocument) -> [(PDFAnnotation, Int)] {
        var result: [(PDFAnnotation, Int)] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations {
                result.append((annotation, i))
            }
        }
        return result
    }

    func annotations(by author: String, in document: PDFDocument) -> [(PDFAnnotation, Int)] {
        allAnnotations(in: document).filter { $0.0.userName == author }
    }

    func annotationTypeString(_ annotation: PDFAnnotation) -> String {
        annotation.type ?? "unknown"
    }
}
