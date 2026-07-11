import Foundation
import SwiftData

@Model
final class DocumentRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var fileName: String
    var createdAt: Date
    var updatedAt: Date
    var fileSize: Int64
    var pageCount: Int
    var kindRaw: String
    var isFavorite: Bool

    init(id: UUID = UUID(), title: String, fileName: String, createdAt: Date = .now, updatedAt: Date = .now, fileSize: Int64 = 0, pageCount: Int = 0, kind: DocumentKind = .pdf, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.kindRaw = kind.rawValue
        self.isFavorite = isFavorite
    }

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .pdf }
        set { kindRaw = newValue.rawValue }
    }
}

enum DocumentKind: String, Codable, CaseIterable {
    case pdf
    case image
    case text
}

@Model
final class OCRHistoryRecord {
    @Attribute(.unique) var id: UUID
    var documentID: UUID?
    var title: String
    var text: String
    var language: String
    var createdAt: Date

    init(id: UUID = UUID(), documentID: UUID? = nil, title: String, text: String, language: String = "en-US", createdAt: Date = .now) {
        self.id = id
        self.documentID = documentID
        self.title = title
        self.text = text
        self.language = language
        self.createdAt = createdAt
    }
}

@Model
final class SignatureRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var imageData: Data
    var createdAt: Date

    init(id: UUID = UUID(), name: String, imageData: Data, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.createdAt = createdAt
    }
}
