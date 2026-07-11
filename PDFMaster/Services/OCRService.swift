import PDFKit
import UIKit
import Vision

struct OCRResult: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
    let confidence: VNConfidence
}

actor OCRService {
    static let shared = OCRService()

    func recognizeText(in image: UIImage, languages: [String] = ["en-US"]) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = (request.results as? [VNRecognizedTextObservation])?.compactMap { observation -> OCRResult? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult(text: candidate.string, boundingBox: observation.boundingBox, confidence: candidate.confidence)
                } ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            do { try handler.perform([request]) } catch { continuation.resume(throwing: error) }
        }
    }

    func recognizeText(inPDF url: URL, languages: [String] = ["en-US"]) async throws -> String {
        guard let document = PDFDocument(url: url) else { throw PDFProcessingError.unreadableDocument }
        var chunks: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let image = page.thumbnail(of: CGSize(width: 1400, height: 1800), for: .mediaBox)
            let pageText = try await recognizeText(in: image, languages: languages).map(\.text).joined(separator: "\n")
            chunks.append(pageText)
        }
        return chunks.joined(separator: "\n\n")
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
