import SwiftUI

enum AppTheme {
    static let primary = Color(red: 1.0, green: 0.168, blue: 0.168)
    static let secondary = Color(red: 0.847, green: 0, blue: 0)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let cardRadius: CGFloat = 18

    static var redGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func premiumCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    func redButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppTheme.redGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.primary.opacity(0.28), radius: 14, y: 8)
    }
}
