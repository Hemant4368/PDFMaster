import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection = 0

    private let pages = [
        OnboardingPage(title: "Scan Documents", subtitle: "Turn paper into crisp multipage PDFs with automatic edges.", icon: "viewfinder", redBackground: true),
        OnboardingPage(title: "Convert Files", subtitle: "Make PDFs from images and export pages as high-quality images.", icon: "arrow.triangle.2.circlepath.doc.on.clipboard", redBackground: false),
        OnboardingPage(title: "OCR Scanner", subtitle: "Recognize text from scans, edit it, copy it, and save history.", icon: "text.viewfinder", redBackground: true),
        OnboardingPage(title: "Secure PDFs", subtitle: "Protect sensitive files with passwords and local app lock.", icon: "lock.shield", redBackground: false),
        OnboardingPage(title: "Merge PDFs", subtitle: "Combine, reorder, extract, sign, annotate, and watermark files.", icon: "square.stack.3d.down.forward", redBackground: true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { hasCompletedOnboarding = true }
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)
                    .padding()
            }
            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        ZStack {
                            if page.redBackground {
                                AppTheme.redGradient
                            } else {
                                Color(.systemBackground)
                            }
                            Circle()
                                .stroke(page.redBackground ? .white.opacity(0.24) : AppTheme.primary.opacity(0.14), lineWidth: 30)
                                .frame(width: 260, height: 260)
                            Image(systemName: page.icon)
                                .font(.system(size: 86, weight: .bold))
                                .foregroundStyle(page.redBackground ? .white : AppTheme.primary)
                        }
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .padding(.horizontal, 20)

                        Text(page.title)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text(page.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selection ? AppTheme.primary : Color.secondary.opacity(0.22))
                        .frame(width: index == selection ? 26 : 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            PrimaryButton(title: selection == pages.count - 1 ? "Get Started" : "Continue", systemImage: "arrow.right") {
                if selection == pages.count - 1 {
                    hasCompletedOnboarding = true
                } else {
                    withAnimation { selection += 1 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let redBackground: Bool
}
