import UIKit

struct ShareFileType {
    let icon: String
    let color: UIColor
    let tools: [ToolItem]

    struct ToolItem {
        let key: String
        let name: String
        let icon: String
    }

    static func infer(from url: URL) -> ShareFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return ShareFileType(
                icon: "doc.richtext",
                color: .systemRed,
                tools: [
                    ToolItem(key: "merge", name: "Merge PDFs", icon: "square.stack.3d.down.forward"),
                    ToolItem(key: "compress", name: "Compress PDF", icon: "arrow.down.to.line.compact"),
                    ToolItem(key: "watermark", name: "Watermark", icon: "doc.text.fill"),
                    ToolItem(key: "password", name: "Password Protect", icon: "lock.shield"),
                    ToolItem(key: "rotate", name: "Rotate PDF", icon: "rotate.right"),
                    ToolItem(key: "ocr", name: "OCR Text", icon: "text.viewfinder"),
                    ToolItem(key: "split", name: "Split PDF", icon: "scissors"),
                    ToolItem(key: "extract", name: "Extract Pages", icon: "doc.on.doc"),
                    ToolItem(key: "reorder", name: "Reorder Pages", icon: "arrow.up.arrow.down.square"),
                    ToolItem(key: "signature", name: "Sign PDF", icon: "signature"),
                    ToolItem(key: "redact", name: "Redact PDF", icon: "rectangle.fill.on.rectangle.fill"),
                ]
            )
        case "jpg", "jpeg", "png", "heic", "webp":
            return ShareFileType(
                icon: "photo",
                color: .systemGreen,
                tools: [
                    ToolItem(key: "imageToPDF", name: "Image to PDF", icon: "photo.on.rectangle"),
                ]
            )
        case "doc", "docx":
            return ShareFileType(
                icon: "doc.text",
                color: .systemBlue,
                tools: [
                    ToolItem(key: "wordToPDF", name: "Word to PDF", icon: "doc.richtext"),
                ]
            )
        case "ppt", "pptx":
            return ShareFileType(
                icon: "play.rectangle",
                color: .systemOrange,
                tools: [
                    ToolItem(key: "pptToPDF", name: "PowerPoint to PDF", icon: "play.rectangle"),
                ]
            )
        case "xls", "xlsx":
            return ShareFileType(
                icon: "tablecells",
                color: .systemGreen,
                tools: [
                    ToolItem(key: "excelToPDF", name: "Excel to PDF", icon: "tablecells"),
                ]
            )
        default:
            return ShareFileType(
                icon: "doc",
                color: .systemGray,
                tools: [
                    ToolItem(key: "imageToPDF", name: "Convert to PDF", icon: "doc.richtext"),
                ]
            )
        }
    }
}
