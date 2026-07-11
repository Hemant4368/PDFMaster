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
        case .unreadableDocument: "The PDF could not be opened."
        case .invalidPageSelection: "Choose at least one valid page."
        case .writeFailed: "The PDF could not be written."
        case .emptyInput: "Choose at least one file or image."
        case .passwordRequired: "This PDF requires a password."
        }
    }
}

actor PDFProcessingService {
    static let shared = PDFProcessingService()

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
            if index == pageIndex {
                signature.draw(in: rect)
            }
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
        case .topLeft: CGPoint(x: inset, y: inset)
        case .topRight: CGPoint(x: bounds.width - textSize.width - inset, y: inset)
        case .center: CGPoint(x: (bounds.width - textSize.width) / 2, y: (bounds.height - textSize.height) / 2)
        case .bottomLeft: CGPoint(x: inset, y: bounds.height - textSize.height - inset)
        case .bottomRight: CGPoint(x: bounds.width - textSize.width - inset, y: bounds.height - textSize.height - inset)
        }
    }
}
