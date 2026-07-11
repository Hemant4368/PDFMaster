import Foundation

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension URL {
    var displayTitle: String {
        deletingPathExtension().lastPathComponent
    }
}

extension Date {
    var shortDocumentDate: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }
}
