import Foundation
import PDFKit
import UIKit

actor FileStorageService {
    static let shared = FileStorageService()

    let documentsDirectory: URL
    let thumbnailsDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        documentsDirectory = base.appendingPathComponent("PDFMaster/Documents", isDirectory: true)
        thumbnailsDirectory = base.appendingPathComponent("PDFMaster/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    func initialize() throws {
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    func url(for fileName: String) -> URL {
        documentsDirectory.appendingPathComponent(fileName)
    }

    func save(data: Data, suggestedName: String, extension ext: String = "pdf") throws -> URL {
        try initialize()
        let sanitized = suggestedName.replacingOccurrences(of: "/", with: "-")
        let name = sanitized.hasSuffix(".\(ext)") ? sanitized : "\(sanitized).\(ext)"
        var destination = documentsDirectory.appendingPathComponent(name)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = documentsDirectory.appendingPathComponent("\(sanitized)-\(counter).\(ext)")
            counter += 1
        }
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    func importFile(from source: URL) throws -> URL {
        try initialize()
        let hasAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { source.stopAccessingSecurityScopedResource() }
        }
        var destination = documentsDirectory.appendingPathComponent(source.lastPathComponent)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = documentsDirectory.appendingPathComponent("\(source.displayTitle)-\(counter).\(source.pathExtension)")
            counter += 1
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    func delete(_ fileName: String) throws {
        let target = url(for: fileName)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }

    func duplicate(_ fileName: String) throws -> URL {
        let source = url(for: fileName)
        let copyName = "\(source.displayTitle) Copy.\(source.pathExtension)"
        var destination = documentsDirectory.appendingPathComponent(copyName)
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = documentsDirectory.appendingPathComponent("\(source.displayTitle) Copy \(counter).\(source.pathExtension)")
            counter += 1
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    func rename(_ fileName: String, to newTitle: String) throws -> URL {
        let source = url(for: fileName)
        let ext = source.pathExtension.isEmpty ? "pdf" : source.pathExtension
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let baseName = sanitized.isEmpty ? source.displayTitle : sanitized
        let normalizedName = baseName.hasSuffix(".\(ext)") ? baseName : "\(baseName).\(ext)"
        var destination = documentsDirectory.appendingPathComponent(normalizedName)

        if source.standardizedFileURL == destination.standardizedFileURL {
            return source
        }

        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = documentsDirectory.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }

        try FileManager.default.moveItem(at: source, to: destination)
        return destination
    }

    func thumbnail(for url: URL, size: CGSize = CGSize(width: 180, height: 240)) async -> UIImage? {
        if let document = PDFDocument(url: url), let page = document.page(at: 0) {
            return page.thumbnail(of: size, for: .cropBox)
        }
        return nil
    }
}

extension FileStorageService {
    nonisolated static func fileURL(for fileName: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("PDFMaster/Documents", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
