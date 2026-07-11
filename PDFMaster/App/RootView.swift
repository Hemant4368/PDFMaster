import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var appLockManager: AppLockManager
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale))
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else if appLockManager.isUnlocked {
                MainTabView()
            } else {
                LockedView()
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            showSplash = false
        }
    }
}

struct LockedView: View {
    @EnvironmentObject private var appLockManager: AppLockManager
    @AppStorage("settings.appLockEnabled") private var appLockEnabled = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primary)
            Text("PDF Master AI Locked")
                .font(.title2.bold())
            PrimaryButton(title: "Unlock", systemImage: "faceid") {
                Task { await appLockManager.authenticateIfNeeded(enabled: appLockEnabled) }
            }
            .padding(.horizontal)
        }
    }
}
