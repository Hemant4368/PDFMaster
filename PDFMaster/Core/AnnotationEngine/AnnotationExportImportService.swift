import PDFKit
import SwiftUI

enum AnnotationExportFormat {
    case xfdf
    case fdf
    case flattenedPDF
    case editablePDF
}

@MainActor
final class AnnotationExportImportService {
    static let shared = AnnotationExportImportService()

    func exportAnnotations(from document: PDFDocument, format: AnnotationExportFormat) -> Data? {
        switch format {
        case .xfdf: return exportXFDF(document)
        case .fdf:  return exportFDF(document)
        case .flattenedPDF: return flattenPDF(document)
        case .editablePDF:  return document.dataRepresentation()
        }
    }

    func importAnnotations(into document: PDFDocument, from data: Data, format: AnnotationExportFormat) {
        switch format {
        case .xfdf: importXFDF(data, into: document)
        case .fdf:  importFDF(data, into: document)
        default: break
        }
    }

    func mergeAnnotations(from source: PDFDocument, into target: PDFDocument) {
        let minPages = min(source.pageCount, target.pageCount)
        for i in 0..<minPages {
            guard let sourcePage = source.page(at: i),
                  let targetPage = target.page(at: i) else { continue }
            for annotation in sourcePage.annotations {
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: annotation, requiringSecureCoding: false),
                      let copy = try? NSKeyedUnarchiver.unarchivedObject(ofClass: PDFAnnotation.self, from: data) else { continue }
                targetPage.addAnnotation(copy)
            }
        }
    }

    private func exportXFDF(_ document: PDFDocument) -> Data? {
        var xfdf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
        <annots>
        """
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations {
                let rect = annotation.bounds
                let pageRect = page.bounds(for: .mediaBox)
                let rectStr = "\(rect.origin.x),\(pageRect.height - rect.origin.y - rect.height),\(rect.width),\(rect.height)"
                let color = annotation.color
                let colorStr = "\(Int(color.cgColor.components?[0] ?? 0 * 255)),\(Int(color.cgColor.components?[1] ?? 0 * 255)),\(Int(color.cgColor.components?[2] ?? 0 * 255))"
                xfdf += """
                <annots type="\(annotation.type)" page="\(i)" rect="\(rectStr)" color="#\(String(format: "%02X%02X%02X", Int(color.cgColor.components?[0] ?? 0 * 255), Int(color.cgColor.components?[1] ?? 0 * 255), Int(color.cgColor.components?[2] ?? 0 * 255)))" />
                """
            }
        }
        xfdf += """
        </annots>
        </xfdf>
        """
        return xfdf.data(using: .utf8)
    }

    private func exportFDF(_ document: PDFDocument) -> Data? {
        var fdf = "%FDF-1.2\n1 0 obj\n<< /FDF /Annots [\n"
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations {
                let rect = annotation.bounds
                fdf += "<< /Type /Annot /Subtype /\(annotation.type) /Rect [\(rect.origin.x) \(rect.origin.y) \(rect.maxX) \(rect.maxY)] /Page \(i) >>\n"
            }
        }
        fdf += "] >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
        return fdf.data(using: .ascii)
    }

    private func importXFDF(_ data: Data, into document: PDFDocument) {}

    private func importFDF(_ data: Data, into document: PDFDocument) {}

    private func flattenPDF(_ document: PDFDocument) -> Data? {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            context.beginPDFPage([:] as CFDictionary)
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            for annotation in page.annotations {
                UIColor.black.setStroke()
                annotation.draw(with: .mediaBox, in: context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }
}
