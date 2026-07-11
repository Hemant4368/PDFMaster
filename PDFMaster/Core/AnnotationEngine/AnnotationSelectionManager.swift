import PDFKit
import SwiftUI

@MainActor
final class AnnotationSelectionManager: ObservableObject {
    @Published private(set) var selectedAnnotation: PDFAnnotation?
    @Published private(set) var selectedAnnotations: Set<AnnotationID> = []
    @Published var isMultiSelect = false

    weak var pdfView: PDFView?

    var hasSelection: Bool { selectedAnnotation != nil }
    var selectionCount: Int { selectedAnnotations.count }

    func select(_ annotation: PDFAnnotation) {
        if isMultiSelect {
            let id = annotation.annotationID
            if selectedAnnotations.contains(id) {
                selectedAnnotations.remove(id)
                if selectedAnnotations.isEmpty {
                    selectedAnnotation = nil
                }
            } else {
                selectedAnnotations.insert(id)
                selectedAnnotation = annotation
            }
        } else {
            selectedAnnotation = annotation
            selectedAnnotations = [annotation.annotationID]
        }
        highlightAnnotation(annotation)
    }

    func deselectAll() {
        selectedAnnotation = nil
        selectedAnnotations.removeAll()
        clearHighlight()
    }

    func selectNext() {
        guard let pdfView, let document = pdfView.document else { return }
        let allAnnotations = allAnnotationsInDocument(document)
        guard let current = selectedAnnotation,
              let index = allAnnotations.firstIndex(where: { $0 === current }),
              index + 1 < allAnnotations.count else { return }
        select(allAnnotations[index + 1])
        jumpToAnnotation(allAnnotations[index + 1])
    }

    func selectPrevious() {
        guard let pdfView, let document = pdfView.document else { return }
        let allAnnotations = allAnnotationsInDocument(document)
        guard let current = selectedAnnotation,
              let index = allAnnotations.firstIndex(where: { $0 === current }),
              index > 0 else { return }
        select(allAnnotations[index - 1])
        jumpToAnnotation(allAnnotations[index - 1])
    }

    func jumpToAnnotation(_ annotation: PDFAnnotation) {
        guard let pdfView, let page = annotation.page else { return }
        pdfView.go(to: PDFDestination(page: page, at: annotation.bounds.origin))
    }

    func deleteSelected() {
        guard let annotation = selectedAnnotation, let page = annotation.page else { return }
        page.removeAnnotation(annotation)
        deselectAll()
    }

    func duplicateSelected() {
        guard let annotation = selectedAnnotation, let page = annotation.page else { return }
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: annotation, requiringSecureCoding: false),
              let copy = try? NSKeyedUnarchiver.unarchivedObject(ofClass: PDFAnnotation.self, from: data) else { return }
        copy.bounds = annotation.bounds.offsetBy(dx: 20, dy: -20)
        page.addAnnotation(copy)
        select(copy)
    }

    private func highlightAnnotation(_ annotation: PDFAnnotation) {
        annotation.color = annotation.color.withAlphaComponent(annotation.color.cgColor.alpha)
    }

    private func clearHighlight() {}

    private func allAnnotationsInDocument(_ document: PDFDocument) -> [PDFAnnotation] {
        var result: [PDFAnnotation] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            result.append(contentsOf: page.annotations)
        }
        return result
    }
}
