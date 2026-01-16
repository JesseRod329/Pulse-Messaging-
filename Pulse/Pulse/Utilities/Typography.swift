//
//  Typography.swift
//  Pulse
//
//  Centralized typography system for Pulse iOS app
//  Code-First Hybrid: SF Mono for UI chrome, SF Pro Text for content
//

import SwiftUI

// MARK: - Typography Constants

struct Typography {
    // Standardized font scale
    static let micro: CGFloat = 11
    static let caption: CGFloat = 13
    static let small: CGFloat = 14
    static let secondary: CGFloat = 15
    static let body: CGFloat = 16
    static let navigation: CGFloat = 17
    static let header: CGFloat = 20
    static let title: CGFloat = 28
    static let largeTitle: CGFloat = 34
    static let display: CGFloat = 48
}

// MARK: - Font Extensions

extension Font {
    // MARK: - Headlines & UI Chrome (SF Mono - Terminal Aesthetic)

    /// Large title for main screens (34pt, bold, SF Mono)
    static var pulseTitle: Font {
        .custom("SF Mono", size: Typography.largeTitle)
            .weight(.bold)
    }

    /// Page titles (28pt, bold, SF Mono)
    static var pulsePageTitle: Font {
        .custom("SF Mono", size: Typography.title)
            .weight(.bold)
    }

    /// Section headers within views (20pt, semibold, SF Mono)
    static var pulseSectionHeader: Font {
        .custom("SF Mono", size: Typography.header)
            .weight(.semibold)
    }

    /// User handles and developer identifiers (16pt, medium, SF Mono)
    static var pulseHandle: Font {
        .custom("SF Mono", size: Typography.body)
            .weight(.medium)
    }

    /// Code snippets and technical content (14pt, regular, SF Mono)
    static var pulseCode: Font {
        .custom("SF Mono", size: Typography.small)
    }

    /// Navigation and toolbar items (17pt, semibold, SF Mono)
    static var pulseNavigation: Font {
        .custom("SF Mono", size: Typography.navigation)
            .weight(.semibold)
    }

    // MARK: - Body Content (SF Pro Text - Readability)

    /// Primary body text for messages and content (16pt, regular)
    static var pulseBody: Font {
        .system(size: Typography.body)
    }

    /// Secondary body text and subtitles (15pt, regular)
    static var pulseBodySecondary: Font {
        .system(size: Typography.secondary)
    }

    /// Captions and supporting text (13pt, regular)
    static var pulseCaption: Font {
        .system(size: Typography.caption)
    }

    /// Labels and UI elements (14pt, medium)
    static var pulseLabel: Font {
        .system(size: Typography.small, weight: .medium)
    }

    // MARK: - Special Purpose

    /// Button text (16pt, semibold)
    static var pulseButton: Font {
        .system(size: Typography.body, weight: .semibold)
    }

    /// Timestamps with monospaced digits (11pt, monospaced)
    static var pulseTimestamp: Font {
        .system(size: Typography.micro)
            .monospacedDigit()
    }

    /// Display text for onboarding/hero screens (48pt, bold, SF Mono)
    static var pulseDisplay: Font {
        .custom("SF Mono", size: Typography.display)
            .weight(.bold)
    }

    // MARK: - Dynamic Type Support

    /// Large title with Dynamic Type support
    static func pulseTitle(withTextStyle style: Font.TextStyle = .largeTitle) -> Font {
        .custom("SF Mono", size: Typography.largeTitle, relativeTo: style)
            .weight(.bold)
    }

    /// Page title with Dynamic Type support
    static func pulsePageTitle(withTextStyle style: Font.TextStyle = .title) -> Font {
        .custom("SF Mono", size: Typography.title, relativeTo: style)
            .weight(.bold)
    }

    /// Section header with Dynamic Type support
    static func pulseSectionHeader(withTextStyle style: Font.TextStyle = .title2) -> Font {
        .custom("SF Mono", size: Typography.header, relativeTo: style)
            .weight(.semibold)
    }

    /// Handle with Dynamic Type support
    static func pulseHandle(withTextStyle style: Font.TextStyle = .body) -> Font {
        .custom("SF Mono", size: Typography.body, relativeTo: style)
            .weight(.medium)
    }

    /// Code with Dynamic Type support
    static func pulseCode(withTextStyle style: Font.TextStyle = .body) -> Font {
        .custom("SF Mono", size: Typography.small, relativeTo: style)
    }

    /// Body with Dynamic Type support
    static func pulseBody(withTextStyle style: Font.TextStyle = .body) -> Font {
        .system(size: Typography.body, design: .default)
    }

    /// Display with Dynamic Type support
    static func pulseDisplay(withTextStyle style: Font.TextStyle = .largeTitle) -> Font {
        .custom("SF Mono", size: Typography.display, relativeTo: style)
            .weight(.bold)
    }
}

// MARK: - Custom Font Extension (SF Mono Support)

extension Font {
    /// Creates a custom SF Mono font with the specified configuration
    static func sfMono(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle? = nil) -> Font {
        if let textStyle = textStyle {
            return .custom("SF Mono", size: size, relativeTo: textStyle).weight(weight)
        } else {
            return .custom("SF Mono", size: size).weight(weight)
        }
    }
}

// MARK: - View Extension for Typography

extension View {
    /// Apply Pulse title style with optional Dynamic Type support
    func pulseTitleStyle(dynamicType: Bool = false) -> some View {
        self.font(dynamicType ? .pulseTitle(withTextStyle: .largeTitle) : .pulseTitle)
    }

    /// Apply Pulse section header style with optional Dynamic Type support
    func pulseSectionHeaderStyle(dynamicType: Bool = false) -> some View {
        self.font(dynamicType ? .pulseSectionHeader(withTextStyle: .title2) : .pulseSectionHeader)
    }

    /// Apply Pulse handle style with optional Dynamic Type support
    func pulseHandleStyle(dynamicType: Bool = false) -> some View {
        self.font(dynamicType ? .pulseHandle(withTextStyle: .body) : .pulseHandle)
    }

    /// Apply Pulse body style with optional Dynamic Type support
    func pulseBodyStyle(dynamicType: Bool = false) -> some View {
        self.font(dynamicType ? .pulseBody(withTextStyle: .body) : .pulseBody)
    }
}
