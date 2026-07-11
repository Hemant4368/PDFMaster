import PDFKit
import SwiftData
import Foundation

@MainActor
enum SaveDocumentHelper {
    static func savePDF(data: Data, title: String, modelContext: ModelContext) async throws -> DocumentRecord {
        let url = try await FileStorageService.shared.save(data: data, suggestedName: title, extension: "pdf")
        let pdf = PDFDocument(url: url)
        let size = await FileStorageService.shared.fileSize(at: url)
        let record = DocumentRecord(title: url.displayTitle, fileName: url.lastPathComponent, fileSize: size, pageCount: pdf?.pageCount ?? 0)
        modelContext.insert(record)
        try modelContext.save()
        return record
    }
}
