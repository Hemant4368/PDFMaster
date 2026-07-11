import UIKit

struct ShareFileType {
    let icon: String
    let color: UIColor
    let tools: [ToolItem]

    struct ToolItem {
        // key MUST equal PDFTool.rawValue in the main app so ShareInbox can resolve it
        let key: String
        let name: String
        let icon: String
    }

    static func infer(from url: URL) -> ShareFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {

        case "pdf":
            return ShareFileType(icon: "doc.richtext.fill", color: .systemRed, tools: [
                ToolItem(key: "Compress PDF",     name: "Compress PDF",       icon: "arrow.down.to.line.compact"),
                ToolItem(key: "Merge PDFs",       name: "Merge PDFs",         icon: "square.stack.3d.down.forward"),
                ToolItem(key: "Split PDF",        name: "Split PDF",          icon: "scissors"),
                ToolItem(key: "Rotate PDF",       name: "Rotate Pages",       icon: "rotate.right.fill"),
                ToolItem(key: "Watermark",        name: "Watermark",          icon: "pencil.and.outline"),
                ToolItem(key: "OCR Text",         name: "Extract Text (OCR)", icon: "text.viewfinder"),
                ToolItem(key: "PDF to Image",     name: "PDF to Image",       icon: "photo.stack"),
                ToolItem(key: "Password",         name: "Password Protect",   icon: "lock.shield.fill"),
                ToolItem(key: "Signature",        name: "Sign PDF",           icon: "signature"),
                ToolItem(key: "Extract Pages",    name: "Extract Pages",      icon: "doc.on.doc.fill"),
                ToolItem(key: "Redact PDF",       name: "Redact PDF",         icon: "rectangle.fill.on.rectangle.fill"),
                ToolItem(key: "AI Summarizer",    name: "AI Summarize",       icon: "sparkles.rectangle.stack"),
                ToolItem(key: "Translate PDF",    name: "Translate PDF",      icon: "character.book.closed"),
                ToolItem(key: "PDF to Markdown",  name: "PDF to Markdown",    icon: "chevron.left.forwardslash.chevron.right"),
            ])

        case "jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tiff", "tif", "bmp":
            return ShareFileType(icon: "photo.fill", color: .systemPurple, tools: [
                ToolItem(key: "Image to PDF", name: "Image to PDF", icon: "photo.on.rectangle.angled"),
            ])

        case "doc", "docx":
            return ShareFileType(icon: "doc.fill", color: .systemBlue, tools: [
                ToolItem(key: "Word to PDF", name: "Word to PDF", icon: "doc.richtext.fill"),
            ])

        case "ppt", "pptx":
            return ShareFileType(icon: "play.rectangle.fill", color: .systemOrange, tools: [
                ToolItem(key: "PowerPoint to PDF", name: "PowerPoint to PDF", icon: "doc.richtext.fill"),
            ])

        case "xls", "xlsx":
            return ShareFileType(icon: "tablecells.fill", color: .systemGreen, tools: [
                ToolItem(key: "Excel to PDF", name: "Excel to PDF", icon: "doc.richtext.fill"),
            ])

        case "txt", "text":
            return ShareFileType(icon: "doc.plaintext.fill", color: .systemGray, tools: [
                ToolItem(key: "Text to PDF", name: "Text to PDF", icon: "doc.richtext.fill"),
            ])

        case "rtf", "rtfd":
            return ShareFileType(icon: "doc.richtext", color: .systemIndigo, tools: [
                ToolItem(key: "RTF to PDF", name: "RTF to PDF", icon: "doc.richtext.fill"),
            ])

        default:
            return ShareFileType(icon: "doc.fill", color: .systemGray, tools: [])
        }
    }
}
