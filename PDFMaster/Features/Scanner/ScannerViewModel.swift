import PDFKit
import SwiftData
import SwiftUI

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var scannedImages: [UIImage] = []
    @Published var title = "Scanned Document"
    @Published var savedDocument: DocumentRecord?
    @Published var isSaving = false
    @Published var errorMessage: String?

    var canSave: Bool { !scannedImages.isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func save(modelContext: ModelContext) {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let data = try await PDFProcessingService.shared.makePDF(from: scannedImages, quality: .high)
                let url = try await FileStorageService.shared.save(data: data, suggestedName: title, extension: "pdf")
                let size = await FileStorageService.shared.fileSize(at: url)
                let record = DocumentRecord(title: url.displayTitle, fileName: url.lastPathComponent, fileSize: size, pageCount: scannedImages.count)
                modelContext.insert(record)
                try modelContext.save()
                savedDocument = record
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
