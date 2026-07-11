import SwiftData
import SwiftUI

@main
struct PDFMasterApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var appLockManager = AppLockManager()
    @AppStorage("settings.appLockEnabled") private var appLockEnabled = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptionManager)
                .environmentObject(appLockManager)
                .task {
                    try? await FileStorageService.shared.initialize()
                    await subscriptionManager.loadProducts()
                    await appLockManager.authenticateIfNeeded(enabled: appLockEnabled)
                }
        }
        .modelContainer(for: [DocumentRecord.self, OCRHistoryRecord.self, SignatureRecord.self])
    }
}
