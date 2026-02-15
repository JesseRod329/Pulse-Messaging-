import SwiftUI

enum AppTheme {
    static let brandSymbolName = "shippingbox.fill"
    static let screenHorizontalPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 100
    static let minimumViewportFill: CGFloat = 0
    static let cardPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 12
    static let floatingActionBarBottomInset: CGFloat = 74
    static let tabBarOverlayHeight: CGFloat = 84
    static let tabBarBottomInset: CGFloat = 0

    static let backgroundTop = Color(red: 0.06, green: 0.09, blue: 0.13) // #101722
    static let backgroundBottom = Color(red: 0.06, green: 0.09, blue: 0.13) // #101722
    static let navBar = Color(red: 0.06, green: 0.09, blue: 0.13)
    static let tabBar = Color(red: 0.06, green: 0.09, blue: 0.13)
    static let surface = Color(red: 0.12, green: 0.16, blue: 0.23) // #1E293B
    static let surfaceElevated = Color(red: 0.15, green: 0.20, blue: 0.29)
    static let border = Color(red: 0.20, green: 0.27, blue: 0.33).opacity(0.95) // #334155

    static let accentBlue = Color(red: 0.23, green: 0.52, blue: 0.98)
    static let accentBlueSoft = Color(red: 0.11, green: 0.22, blue: 0.39)
    static let success = Color(red: 0.11, green: 0.73, blue: 0.52)
    static let warning = Color(red: 0.95, green: 0.70, blue: 0.10)
    static let danger = Color(red: 0.95, green: 0.32, blue: 0.32)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textMuted = Color.white.opacity(0.56)

    static let displayFont = Font.system(size: 34, weight: .bold)
    static let titleFont = Font.system(size: 24, weight: .bold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .semibold)

    static let screenGradient = LinearGradient(
        colors: [backgroundTop, Color(red: 0.05, green: 0.10, blue: 0.18), backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [surfaceElevated.opacity(0.96), surface.opacity(0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
