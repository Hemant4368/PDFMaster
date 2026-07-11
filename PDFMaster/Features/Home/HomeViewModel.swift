import PDFKit
import SwiftData
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var query = ""
    @Published var thumbnails: [UUID: UIImage] = [:]
    @Published var pickedDocument: DocumentRecord?
    @Published var sharePayload: SharePayload?
    @Published var errorMessage: String?
    @Published var isImporting = false

    func filtered(_ documents: [DocumentRecord]) -> [DocumentRecord] {
        let sorted = documents.sorted { $0.updatedAt > $1.updatedAt }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    func loadThumbnails(for documents: [DocumentRecord]) {
        Task {
            for document in documents where thumbnails[document.id] == nil {
                let url = await FileStorageService.shared.url(for: document.fileName)
                if let image = await FileStorageService.shared.thumbnail(for: url) {
                    thumbnails[document.id] = image
                }
            }
        }
    }

    func importFiles(_ urls: [URL], modelContext: ModelContext) {
        Task {
            isImporting = true
            defer { isImporting = false }
            for url in urls {
                do {
                    let destination = try await FileStorageService.shared.importFile(from: url)
                    let document = PDFDocument(url: destination)
                    let size = await FileStorageService.shared.fileSize(at: destination)
                    let record = DocumentRecord(title: destination.displayTitle, fileName: destination.lastPathComponent, fileSize: size, pageCount: document?.pageCount ?? 0)
                    modelContext.insert(record)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            try? modelContext.save()
        }
    }

    func share(_ document: DocumentRecord) {
        Task {
            let url = await FileStorageService.shared.url(for: document.fileName)
            sharePayload = SharePayload(urls: [url])
        }
    }

    func share(_ documents: [DocumentRecord]) {
        Task {
            let urls = await documents.asyncMap { document in
                await FileStorageService.shared.url(for: document.fileName)
            }
            sharePayload = SharePayload(urls: urls)
        }
    }

    func duplicate(_ document: DocumentRecord, modelContext: ModelContext) {
        Task {
            do {
                let newURL = try await FileStorageService.shared.duplicate(document.fileName)
                let size = await FileStorageService.shared.fileSize(at: newURL)
                let record = DocumentRecord(title: newURL.displayTitle, fileName: newURL.lastPathComponent, fileSize: size, pageCount: document.pageCount)
                modelContext.insert(record)
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func rename(_ document: DocumentRecord, to newTitle: String, modelContext: ModelContext) {
        Task {
            do {
                let renamedURL = try await FileStorageService.shared.rename(document.fileName, to: newTitle)
                let size = await FileStorageService.shared.fileSize(at: renamedURL)
                document.title = renamedURL.displayTitle
                document.fileName = renamedURL.lastPathComponent
                document.fileSize = size
                document.updatedAt = .now
                thumbnails[document.id] = nil
                try modelContext.save()
                loadThumbnails(for: [document])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func delete(_ document: DocumentRecord, modelContext: ModelContext) {
        Task {
            do {
                try await FileStorageService.shared.delete(document.fileName)
                modelContext.delete(document)
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func delete(_ documents: [DocumentRecord], modelContext: ModelContext) {
        Task {
            do {
                for document in documents {
                    try await FileStorageService.shared.delete(document.fileName)
                    thumbnails[document.id] = nil
                    modelContext.delete(document)
                }
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            values.append(await transform(element))
        }
        return values
    }
}
