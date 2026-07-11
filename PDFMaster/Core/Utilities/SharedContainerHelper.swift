import Foundation

enum SharedContainerHelper {
    static let appGroupID = "group.com.hp.app.imageTopdf"

    private static var sharedFilesDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("SharedFiles", isDirectory: true)
    }

    // Called by the Share Extension to persist the incoming file and selected tool
    static func saveIncoming(data: Data, filename: String, toolKey: String) throws {
        guard let dir = sharedFilesDir else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(filename), options: .atomic)
        let ud = UserDefaults(suiteName: appGroupID)
        ud?.set(filename, forKey: "pendingShareFilename")
        ud?.set(toolKey,  forKey: "pendingShareTool")
        ud?.synchronize()
    }

    // Called by the main app on URL open — returns the file URL and clears the pending entry
    static func consumeIncoming() -> (toolKey: String, fileURL: URL)? {
        let ud = UserDefaults(suiteName: appGroupID)
        guard let toolKey  = ud?.string(forKey: "pendingShareTool"),
              let filename  = ud?.string(forKey: "pendingShareFilename"),
              let dir = sharedFilesDir else { return nil }
        let fileURL = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ud?.removeObject(forKey: "pendingShareTool")
            ud?.removeObject(forKey: "pendingShareFilename")
            return nil
        }
        ud?.removeObject(forKey: "pendingShareTool")
        ud?.removeObject(forKey: "pendingShareFilename")
        ud?.synchronize()
        return (toolKey, fileURL)
    }
}
