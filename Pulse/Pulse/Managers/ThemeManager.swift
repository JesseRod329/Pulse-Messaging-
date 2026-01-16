//
//  ThemeManager.swift
//  Pulse
//
//  Dynamic theme system for customizing Pulse's appearance.
//

import SwiftUI

/// Available themes in Pulse
enum PulseTheme: String, CaseIterable, Identifiable, Codable {
    case midnight   // Default - deep blue/cyan
    case ember      // Dark with orange/red accents
    case matrix     // Green terminal aesthetic
    case frost      // Light mode with ice blue
    case neon       // Vibrant purple/pink
    case mono       // Minimalist grayscale

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .ember: return "Ember"
        case .matrix: return "Matrix"
        case .frost: return "Frost"
        case .neon: return "Neon"
        case .mono: return "Mono"
        }
    }

    var icon: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .ember: return "flame.fill"
        case .matrix: return "terminal.fill"
        case .frost: return "snowflake"
        case .neon: return "sparkles"
        case .mono: return "circle.lefthalf.filled"
        }
    }

    var isDark: Bool {
        switch self {
        case .frost: return false
        default: return true
        }
    }
}

/// Theme color palette
struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let accentGlow: Color
    let text: Color
    let textSecondary: Color
    let success: Color
    let warning: Color
    let error: Color

    static func colors(for theme: PulseTheme) -> ThemeColors {
        switch theme {
        case .midnight:
            return ThemeColors(
                background: Color(hex: "0A0F1C"),
                secondaryBackground: Color(hex: "0F1629"),
                cardBackground: Color.white.opacity(0.06),
                primary: Color(hex: "00D4FF"),
                secondary: Color(hex: "0099CC"),
                accent: Color(hex: "00D4FF"),
                accentGlow: Color(hex: "00D4FF").opacity(0.3),
                text: .white,
                textSecondary: Color.white.opacity(0.6),
                success: Color(hex: "00FF88"),
                warning: Color(hex: "FFB800"),
                error: Color(hex: "FF4757")
            )
        case .ember:
            return ThemeColors(
                background: Color(hex: "1A0A0A"),
                secondaryBackground: Color(hex: "2A1010"),
                cardBackground: Color(hex: "FF4500").opacity(0.08),
                primary: Color(hex: "FF6B35"),
                secondary: Color(hex: "FF4500"),
                accent: Color(hex: "FF6B35"),
                accentGlow: Color(hex: "FF4500").opacity(0.3),
                text: .white,
                textSecondary: Color.white.opacity(0.6),
                success: Color(hex: "00FF88"),
                warning: Color(hex: "FFB800"),
                error: Color(hex: "FF4757")
            )
        case .matrix:
            return ThemeColors(
                background: Color(hex: "0D0D0D"),
                secondaryBackground: Color(hex: "0A1A0A"),
                cardBackground: Color(hex: "00FF00").opacity(0.05),
                primary: Color(hex: "00FF00"),
                secondary: Color(hex: "00CC00"),
                accent: Color(hex: "00FF00"),
                accentGlow: Color(hex: "00FF00").opacity(0.3),
                text: Color(hex: "00FF00"),
                textSecondary: Color(hex: "00FF00").opacity(0.6),
                success: Color(hex: "00FF00"),
                warning: Color(hex: "FFFF00"),
                error: Color(hex: "FF0000")
            )
        case .frost:
            return ThemeColors(
                background: Color(hex: "F0F4F8"),
                secondaryBackground: Color(hex: "E8EEF4"),
                cardBackground: Color.white.opacity(0.8),
                primary: Color(hex: "0066CC"),
                secondary: Color(hex: "004499"),
                accent: Color(hex: "0088FF"),
                accentGlow: Color(hex: "0088FF").opacity(0.2),
                text: Color(hex: "1A1A2E"),
                textSecondary: Color(hex: "1A1A2E").opacity(0.6),
                success: Color(hex: "00AA55"),
                warning: Color(hex: "FF9500"),
                error: Color(hex: "FF3B30")
            )
        case .neon:
            return ThemeColors(
                background: Color(hex: "0A0A1A"),
                secondaryBackground: Color(hex: "12122A"),
                cardBackground: Color(hex: "FF00FF").opacity(0.06),
                primary: Color(hex: "FF00FF"),
                secondary: Color(hex: "00FFFF"),
                accent: Color(hex: "FF00FF"),
                accentGlow: Color(hex: "FF00FF").opacity(0.4),
                text: .white,
                textSecondary: Color.white.opacity(0.7),
                success: Color(hex: "00FF88"),
                warning: Color(hex: "FFFF00"),
                error: Color(hex: "FF0055")
            )
        case .mono:
            return ThemeColors(
                background: Color(hex: "0A0A0A"),
                secondaryBackground: Color(hex: "141414"),
                cardBackground: Color.white.opacity(0.05),
                primary: Color.white,
                secondary: Color.white.opacity(0.8),
                accent: Color.white,
                accentGlow: Color.white.opacity(0.2),
                text: .white,
                textSecondary: Color.white.opacity(0.5),
                success: Color.white,
                warning: Color.white.opacity(0.8),
                error: Color.white.opacity(0.6)
            )
        }
    }
}

/// Theme manager for the app
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: PulseTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    var colors: ThemeColors {
        ThemeColors.colors(for: currentTheme)
    }

    var colorScheme: ColorScheme {
        currentTheme.isDark ? .dark : .light
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = PulseTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .midnight
        }
    }

    func setTheme(_ theme: PulseTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

