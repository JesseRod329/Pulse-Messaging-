import SwiftUI

enum AppTheme {
    static let brandSymbolName = "shippingbox.fill"
    static let screenHorizontalPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 100
    static let minimumViewportFill: CGFloat = 0
    static let cardPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 12
    static let cardCornerRadiusLarge: CGFloat = 16
    static let floatingActionBarBottomInset: CGFloat = 74
    static let fabBottomPadding: CGFloat = 74
    static let tabBarOverlayHeight: CGFloat = 84
    static let tabBarBottomInset: CGFloat = 0
    static let avatarSizeMedium: CGFloat = 48
    static let avatarSizeLarge: CGFloat = 56
    static let timelineNodeSize: CGFloat = 40
    static let controlHeight: CGFloat = 48

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

    // Inter-based type scale. If Inter is unavailable at runtime, SwiftUI falls back to system.
    static let displayFont = Font.custom("Inter-Bold", size: 34, relativeTo: .largeTitle)
    static let titleFont = Font.custom("Inter-Bold", size: 24, relativeTo: .title2)
    static let bodyFont = Font.custom("Inter-Regular", size: 16, relativeTo: .body)
    static let captionFont = Font.custom("Inter-SemiBold", size: 12, relativeTo: .caption)

    static func inter(
        _ size: CGFloat,
        weight: InterWeight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        Font.custom(weight.fontName, size: size, relativeTo: textStyle)
    }

    static func interMonospaced(
        _ size: CGFloat,
        weight: InterWeight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        inter(size, weight: weight, relativeTo: textStyle).monospaced()
    }

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

    static func chromeBackground(glass: Bool) -> some View {
        Group {
            if glass {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(navBar.opacity(0.50))
            } else {
                Rectangle().fill(navBar.opacity(0.95))
            }
        }
    }

    static func symbolFont(
        _ size: CGFloat,
        weight: Font.Weight = .semibold
    ) -> Font {
        .system(size: size, weight: weight)
    }
}

enum InterWeight {
    case regular
    case medium
    case semibold
    case bold

    var fontName: String {
        switch self {
        case .regular: return "Inter-Regular"
        case .medium: return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold: return "Inter-Bold"
        }
    }
}

enum DesignIcon {
    case feed
    case orders
    case dispatch
    case profile
    case chevronRight
    case chevronDown
    case chevronUp
    case add
    case menu
    case refresh
    case search
    case assign

    var systemName: String {
        switch self {
        case .feed:
            return "newspaper"
        case .orders:
            return "shippingbox"
        case .dispatch:
            return "map"
        case .profile:
            return "person.crop.circle"
        case .chevronRight:
            return "chevron.right"
        case .chevronDown:
            return "chevron.down"
        case .chevronUp:
            return "chevron.up"
        case .add:
            return "plus"
        case .menu:
            return "line.3.horizontal"
        case .refresh:
            return "arrow.clockwise"
        case .search:
            return "magnifyingglass"
        case .assign:
            return "person.badge.plus"
        }
    }
}

struct DesignIconView: View {
    let icon: DesignIcon
    var size: CGFloat = 18
    var color: Color = AppTheme.textPrimary
    @ScaledMetric(relativeTo: .body) private var iconScale: CGFloat = 1

    var body: some View {
        Image(systemName: icon.systemName)
            .font(AppTheme.symbolFont(size * iconScale, weight: .semibold))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
