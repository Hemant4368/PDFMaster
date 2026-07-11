import UniformTypeIdentifiers

struct UTTypeWrapper: Hashable {
    let type: UTType
    static let pdf        = UTTypeWrapper(type: .pdf)
    static let image      = UTTypeWrapper(type: .image)
    static let plainText  = UTTypeWrapper(type: .plainText)
    static let html       = UTTypeWrapper(type: .html)
    static let rtf        = UTTypeWrapper(type: .rtf)
    static let csv        = UTTypeWrapper(type: .commaSeparatedText)
    static let doc        = UTTypeWrapper(type: UTType(filenameExtension: "doc") ?? .data)
    static let docx       = UTTypeWrapper(type: UTType(filenameExtension: "docx") ?? .data)
    static let ppt        = UTTypeWrapper(type: UTType(filenameExtension: "ppt") ?? .data)
    static let pptx       = UTTypeWrapper(type: UTType(filenameExtension: "pptx") ?? .data)
    static let xls        = UTTypeWrapper(type: UTType(filenameExtension: "xls") ?? .data)
    static let xlsx       = UTTypeWrapper(type: UTType(filenameExtension: "xlsx") ?? .data)
    static let markdown   = UTTypeWrapper(type: UTType(filenameExtension: "md") ?? .plainText)
}
