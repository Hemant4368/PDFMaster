import SwiftData
import SwiftUI

@main
struct PDFMasterApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var appLockManager = AppLockManager()
    @StateObject private var shareInbox = ShareInbox.shared
    @AppStorage("settings.appLockEnabled") private var appLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptionManager)
                .environmentObject(appLockManager)
                .environmentObject(shareInbox)
                .task {
                    try? await FileStorageService.shared.initialize()
                    await subscriptionManager.loadProducts()
                    await appLockManager.authenticateIfNeeded(enabled: appLockEnabled)
                }
                .onOpenURL { url in handleIncomingURL(url) }
        }
        .modelContainer(for: [DocumentRecord.self, OCRHistoryRecord.self, SignatureRecord.self])
        .onChange(of: scenePhase) { _, phase in
            // Fallback: if extensionContext.open() didn't fire onOpenURL,
            // pick up the pending share when the app becomes active.
            if phase == .active { checkPendingShare() }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "pdfmaster", url.host == "shareopen" else { return }
        checkPendingShare()
    }

    private func checkPendingShare() {
        guard let (toolKey, fileURL) = SharedContainerHelper.consumeIncoming(),
              let tool = PDFTool.from(shareKey: toolKey) else { return }
        shareInbox.set(tool: tool, url: fileURL)
    }
}
