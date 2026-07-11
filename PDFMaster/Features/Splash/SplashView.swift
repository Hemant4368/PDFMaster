import SwiftUI

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            AppTheme.redGradient.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 12)
                        .frame(width: pulse ? 138 : 118, height: pulse ? 138 : 118)
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(pulse ? 1.06 : 0.92)
                }
                Text("PDF Master AI")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Scanner, Editor & Converter")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
