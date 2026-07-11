import SwiftUI

@MainActor
final class ShareInbox: ObservableObject {
    static let shared = ShareInbox()

    @Published var pendingTool: PDFTool? = nil
    @Published var pendingURL: URL? = nil

    func set(tool: PDFTool, url: URL) {
        pendingTool = tool
        pendingURL = url
    }

    // Consume if this view's tool matches the pending tool
    func consumeURL(for tool: PDFTool) -> URL? {
        guard pendingTool == tool, let url = pendingURL else { return nil }
        pendingTool = nil; pendingURL = nil
        return url
    }
}

extension PDFTool {
    // Key used in URL scheme and App Group UserDefaults
    var shareKey: String { rawValue }

    static func from(shareKey: String) -> PDFTool? {
        PDFTool.allCases.first { $0.shareKey == shareKey }
    }

    // Which file type (UTI prefix) each tool accepts from share sheet
    var shareAcceptsUTI: String {
        switch self {
        case .imageToPDF:              return "public.image"
        case .wordToPDF:               return "org.openxmlformats.wordprocessingml.document"
        case .pptToPDF:                return "org.openxmlformats.presentationml.presentation"
        case .excelToPDF:              return "org.openxmlformats.spreadsheetml.sheet"
        case .txtToPDF:                return "public.plain-text"
        case .rtfToPDF:                return "public.rtf"
        default:                       return "com.adobe.pdf"
        }
    }
}
