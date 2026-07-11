import CoreGraphics
import PDFKit
import SwiftUI
import UIKit

enum PDFProcessingError: LocalizedError {
    case unreadableDocument
    case invalidPageSelection
    case writeFailed
    case emptyInput
    case passwordRequired

    var errorDescription: String? {
        switch self {
        case .unreadableDocument:    "The PDF could not be opened."
        case .invalidPageSelection:  "Choose at least one valid page."
        case .writeFailed:           "The PDF could not be written."
        case .emptyInput:            "Choose at least one file or image."
        case .passwordRequired:      "This PDF requires a password."
        }
    }
}

actor PDFProcessingService {
    static let shared = PDFProcessingService()

    // MARK: — Existing methods

    func makePDF(from images: [UIImage], quality: PDFQuality = .balanced) throws -> Data {
        guard !images.isEmpty else { throw PDFProcessingError.emptyInput }
        let format = UIGraphicsPDFRendererFormat()
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, format.documentInfo)
        for image in images {
            autoreleasepool {
                let maxWidth: CGFloat = 1240
                let scale = min(1, maxWidth / max(image.size.width, 1))
                let pageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: pageSize), nil)
                image.draw(in: CGRect(origin: .zero, size: pageSize))
            }
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    func merge(_ urls: [URL]) throws -> Data {
        guard !urls.isEmpty else { throw PDFProcessingError.emptyInput }
        let output = PDFDocument()
        var outputIndex = 0
        for url in urls {
            guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
            if document.isLocked { throw PDFProcessingError.passwordRequired }
            for index in 0..<document.pageCount {
                if let page = document.page(at: index) {
                    output.insert(page, at: outputIndex)
                    outputIndex += 1
                }
            }
        }
        guard let data = output.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func extractPages(from url: URL, indexes: [Int]) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        guard !indexes.isEmpty else { throw PDFProcessingError.invalidPageSelection }
        let output = PDFDocument()
        for (targetIndex, sourceIndex) in indexes.sorted().enumerated() {
            guard sourceIndex >= 0, sourceIndex < document.pageCount, let page = document.page(at: sourceIndex) else {
                throw PDFProcessingError.invalidPageSelection
            }
            output.insert(page, at: targetIndex)
        }
        guard let data = output.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func removePages(from url: URL, indexes: Set<Int>) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let output = PDFDocument()
        var target = 0
        for index in 0..<document.pageCount where !indexes.contains(index) {
            if let page = document.page(at: index) {
                output.insert(page, at: target)
                target += 1
            }
        }
        guard output.pageCount > 0, let data = output.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func reorderPages(from url: URL, order: [Int]) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        guard order.count == document.pageCount else { throw PDFProcessingError.invalidPageSelection }
        let output = PDFDocument()
        for (newIndex, oldIndex) in order.enumerated() {
            guard let page = document.page(at: oldIndex) else { throw PDFProcessingError.invalidPageSelection }
            output.insert(page, at: newIndex)
        }
        guard let data = output.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func protect(url: URL, password: String) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let options: [PDFDocumentWriteOption: Any] = [
            .ownerPasswordOption: password,
            .userPasswordOption: password
        ]
        guard let data = document.dataRepresentation(options: options) else { throw PDFProcessingError.writeFailed }
        return data
    }

    func unlock(url: URL, password: String) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        if document.isLocked, !document.unlock(withPassword: password) {
            throw PDFProcessingError.passwordRequired
        }
        guard let data = document.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func watermarked(url: URL, options: WatermarkOptions) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, .zero, nil)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            drawWatermark(options: options, in: bounds)
        }
        UIGraphicsEndPDFContext()
        return output as Data
    }

    func signed(url: URL, signature: UIImage, pageIndex: Int, rect: CGRect) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, .zero, nil)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            if index == pageIndex { signature.draw(in: rect) }
        }
        UIGraphicsEndPDFContext()
        return output as Data
    }

    func renderImages(from url: URL, format: PDFExportFormat, scale: CGFloat = 2) throws -> [Data] {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        return (0..<document.pageCount).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            return format == .png ? image.pngData() : image.jpegData(compressionQuality: 0.92)
        }
    }

    // MARK: — New methods

    func split(url: URL, rangesString: String) throws -> [Data] {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let ranges = try parseRanges(rangesString, pageCount: document.pageCount)
        guard !ranges.isEmpty else { throw PDFProcessingError.invalidPageSelection }
        return try ranges.map { indexes in
            let part = PDFDocument()
            for (newIndex, sourceIndex) in indexes.enumerated() {
                guard let page = document.page(at: sourceIndex) else { throw PDFProcessingError.invalidPageSelection }
                part.insert(page, at: newIndex)
            }
            guard let data = part.dataRepresentation() else { throw PDFProcessingError.writeFailed }
            return data
        }
    }

    func compress(url: URL, quality: PDFQuality) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let scale = quality.renderScale
        let compression = quality.imageCompression
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            guard let jpegData = image.jpegData(compressionQuality: compression),
                  let compressed = UIImage(data: jpegData) else { continue }
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            compressed.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        UIGraphicsEndPDFContext()
        guard pdfData.length > 0 else { throw PDFProcessingError.writeFailed }
        return pdfData as Data
    }

    func repair(url: URL) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        guard let data = document.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func rotatePages(url: URL, rotation: Int, pageIndexes: [Int]) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let valid = Set(pageIndexes).filter { $0 >= 0 && $0 < document.pageCount }
        guard !valid.isEmpty else { throw PDFProcessingError.invalidPageSelection }
        for index in valid {
            guard let page = document.page(at: index) else { continue }
            page.rotation = (page.rotation + rotation) % 360
        }
        guard let data = document.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func addPageNumbers(url: URL, startingAt: Int, fontSize: CGFloat, position: PageNumberPosition) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, .zero, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            let text = NSString(string: "\(index + startingAt)")
            let textSize = text.size(withAttributes: attributes)
            let origin = pageNumberOrigin(position: position, textSize: textSize, pageBounds: bounds)
            text.draw(at: origin, withAttributes: attributes)
        }
        UIGraphicsEndPDFContext()
        return output as Data
    }

    func cropPages(url: URL, margins: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let media = page.bounds(for: .mediaBox)
            let cropRect = CGRect(
                x: media.minX + margins.left,
                y: media.minY + margins.bottom,
                width: media.width - margins.left - margins.right,
                height: media.height - margins.top - margins.bottom
            )
            guard cropRect.width > 0, cropRect.height > 0 else { continue }
            page.setBounds(cropRect, for: .cropBox)
        }
        guard let data = document.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    func redact(url: URL, regions: [(pageIndex: Int, rect: CGRect)]) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        let regionsByPage = Dictionary(grouping: regions, by: { $0.pageIndex })
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, .zero, nil)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            if let pageRegions = regionsByPage[index] {
                UIColor.black.setFill()
                pageRegions.forEach { UIRectFill($0.rect) }
            }
        }
        UIGraphicsEndPDFContext()
        return output as Data
    }

    func convertToPDFA(url: URL) throws -> Data {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        var attrs = document.documentAttributes ?? [:]
        attrs[PDFDocumentAttribute.creatorAttribute] = "PDFMaster AI"
        attrs[PDFDocumentAttribute.creationDateAttribute] = Date()
        document.documentAttributes = attrs
        guard let data = document.dataRepresentation() else { throw PDFProcessingError.writeFailed }
        return data
    }

    // MARK: — Private helpers

    private func parseRanges(_ string: String, pageCount: Int) throws -> [[Int]] {
        var result: [[Int]] = []
        let parts = string.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts where !part.isEmpty {
            let bounds = part.components(separatedBy: "-")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard bounds.count == 2,
                  bounds[0] >= 1, bounds[1] <= pageCount, bounds[0] <= bounds[1] else {
                throw PDFProcessingError.invalidPageSelection
            }
            result.append(Array((bounds[0] - 1)...(bounds[1] - 1)))
        }
        return result
    }

    private func pageNumberOrigin(position: PageNumberPosition, textSize: CGSize, pageBounds: CGRect) -> CGPoint {
        let m: CGFloat = 20
        let cx = (pageBounds.width - textSize.width) / 2
        let rx = pageBounds.width - textSize.width - m
        let by = pageBounds.height - textSize.height - m
        return switch position {
        case .topLeft:      CGPoint(x: m,  y: m)
        case .topCenter:    CGPoint(x: cx, y: m)
        case .topRight:     CGPoint(x: rx, y: m)
        case .bottomLeft:   CGPoint(x: m,  y: by)
        case .bottomCenter: CGPoint(x: cx, y: by)
        case .bottomRight:  CGPoint(x: rx, y: by)
        }
    }

    private func drawWatermark(options: WatermarkOptions, in bounds: CGRect) {
        let uiColor = UIColor(options.color).withAlphaComponent(options.opacity)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: options.fontSize),
            .foregroundColor: uiColor
        ]
        let text = NSString(string: options.text)
        let size = text.size(withAttributes: attributes)
        let origin = watermarkOrigin(for: options.position, textSize: size, bounds: bounds)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        context.rotate(by: options.rotation * .pi / 180)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        context.restoreGState()
    }

    private func watermarkOrigin(for position: WatermarkPosition, textSize: CGSize, bounds: CGRect) -> CGPoint {
        let inset: CGFloat = 40
        return switch position {
        case .topLeft:     CGPoint(x: inset, y: inset)
        case .topRight:    CGPoint(x: bounds.width - textSize.width - inset, y: inset)
        case .center:      CGPoint(x: (bounds.width - textSize.width) / 2, y: (bounds.height - textSize.height) / 2)
        case .bottomLeft:  CGPoint(x: inset, y: bounds.height - textSize.height - inset)
        case .bottomRight: CGPoint(x: bounds.width - textSize.width - inset, y: bounds.height - textSize.height - inset)
        }
    }
}
