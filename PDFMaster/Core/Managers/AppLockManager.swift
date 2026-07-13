import Foundation
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isUnlocked = true
    @Published var errorMessage: String?

    func authenticateIfNeeded(enabled: Bool) async {
        guard enabled else {
            isUnlocked = true
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription
            isUnlocked = false
            return
        }
        do {
            isUnlocked = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock PDF Converter")
        } catch {
            errorMessage = error.localizedDescription
            isUnlocked = false
        }
    }
}
