import SwiftUI

enum AppTheme {
    static let brandSymbolName = "custom.truck.box.badge.clock.fill"
    static let screenHorizontalPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 118
    static let minimumViewportFill: CGFloat = 0
    static let cardPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 14
    static let floatingActionBarBottomInset: CGFloat = 74
    static let tabBarOverlayHeight: CGFloat = 90
    static let tabBarBottomInset: CGFloat = 10

    static let backgroundTop = Color(red: 0.03, green: 0.11, blue: 0.25)
    static let backgroundBottom = Color(red: 0.06, green: 0.23, blue: 0.49)
    static let navBar = Color(red: 0.05, green: 0.14, blue: 0.30)
    static let tabBar = Color(red: 0.07, green: 0.20, blue: 0.40)
    static let surface = Color(red: 0.08, green: 0.14, blue: 0.25)
    static let surfaceElevated = Color(red: 0.11, green: 0.18, blue: 0.30)
    static let border = Color.white.opacity(0.10)

    static let accentBlue = Color(red: 0.23, green: 0.52, blue: 0.98)
    static let accentBlueSoft = Color(red: 0.16, green: 0.36, blue: 0.64)
    static let success = Color(red: 0.11, green: 0.73, blue: 0.52)
    static let warning = Color(red: 0.95, green: 0.70, blue: 0.10)
    static let danger = Color(red: 0.95, green: 0.32, blue: 0.32)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textMuted = Color.white.opacity(0.56)

    static let displayFont = Font.system(size: 34, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 24, weight: .bold, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 12, weight: .semibold, design: .rounded)

    static let screenGradient = LinearGradient(
        colors: [backgroundTop, Color(red: 0.04, green: 0.18, blue: 0.39), backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [surfaceElevated, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
