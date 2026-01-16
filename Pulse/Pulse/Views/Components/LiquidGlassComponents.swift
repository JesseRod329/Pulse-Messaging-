//
//  LiquidGlassComponents.swift
//  Pulse
//
//  iOS 26 Liquid Glass Design System
//  Complete glass morphism component library
//

import SwiftUI

// MARK: - Glass Configuration

struct GlassConfig {
    let baseTint: Color
    let blurRadius: CGFloat
    let opacity: Double
    let borderOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat

    static let `default` = GlassConfig(
        baseTint: .white,
        blurRadius: 25,
        opacity: 0.15,
        borderOpacity: 0.3,
        shadowColor: .black.opacity(0.2),
        shadowRadius: 16
    )
}

enum LiquidGlassStyle {
    case ultraThin
    case thin
    case regular
    case thick
    case prominent

    var blurRadius: CGFloat {
        switch self {
        case .ultraThin: return 10
        case .thin: return 20
        case .regular: return 30
        case .thick: return 40
        case .prominent: return 50
        }
    }

    var opacity: Double {
        switch self {
        case .ultraThin: return 0.05
        case .thin: return 0.10
        case .regular: return 0.15
        case .thick: return 0.20
        case .prominent: return 0.25
        }
    }
}

// MARK: - Glass Background

struct LiquidGlassBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base dark layer
            Color.black.ignoresSafeArea()

            // Animated organic blobs
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: animate ? 100 : -100, y: animate ? -100 : 100)

                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: animate ? -80 : 80, y: animate ? 80 : -80)
            }
            .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate = true
            }

            // Glass grain/noise effect overlay if needed
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Glass Effect Modifier

struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let tint: Color
    let cornerRadius: CGFloat
    let isInteractive: Bool

    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer with material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Tint overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tint.opacity(style.opacity))

                    // Gradient border for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.05),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: tint.opacity(0.2), radius: 20, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .scaleEffect(isPressed && isInteractive ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

extension View {
    func liquidGlass(
        style: LiquidGlassStyle = .regular,
        tint: Color = .white,
        cornerRadius: CGFloat = 16,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            style: style,
            tint: tint,
            cornerRadius: cornerRadius,
            isInteractive: interactive
        ))
    }
}

// MARK: - Glass Card Component

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let tintColor: Color
    let cornerRadius: CGFloat
    let style: LiquidGlassStyle

    init(
        style: LiquidGlassStyle = .regular,
        tint: Color = .white,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.tintColor = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Tint overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tintColor.opacity(style.opacity))

                    // Gradient border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: tintColor.opacity(0.2), radius: 20, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Glass FAB (Floating Action Button)

struct LiquidGlassFAB: View {
    let icon: String
    let action: () -> Void
    let tint: Color
    let size: CGFloat

    @State private var isPressed = false

    init(
        icon: String,
        tint: Color = .white,
        size: CGFloat = 56,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.tint = tint
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(tint.opacity(0.3))
                            .blur(radius: 20)
                            .scaleEffect(isPressed ? 0.9 : 1.1)

                        // Glass surface
                        Circle()
                            .fill(.ultraThinMaterial)

                        // Tint overlay
                        Circle()
                            .fill(tint.opacity(0.15))

                        // Border shimmer
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        .white.opacity(0.5),
                                        .clear,
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    center: .center
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: tint.opacity(0.4), radius: 16, y: 8)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .scaleEffect(isPressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Glass Button

struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let tint: Color
    let style: LiquidGlassStyle

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        style: LiquidGlassStyle = .regular,
        tint: Color = .white,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Glass base
                    Capsule()
                        .fill(.ultraThinMaterial)

                    // Tint overlay
                    Capsule()
                        .fill(tint.opacity(style.opacity))

                    // Border
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: tint.opacity(0.2), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Glass TextField

struct LiquidGlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let tint: Color

    @State private var isFocused = false

    init(
        _ placeholder: String,
        text: Binding<String>,
        tint: Color = .cyan
    ) {
        self.placeholder = placeholder
        self._text = text
        self.tint = tint
    }

    var body: some View {
        TextField(placeholder, text: $text, onEditingChanged: { editing in
            withAnimation(.spring(response: 0.3)) {
                isFocused = editing
            }
        })
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glass base
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)

                // Tint overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(isFocused ? 0.15 : 0.05))

                // Border with focus glow
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        tint.opacity(isFocused ? 0.6 : 0.2),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
        )
        .shadow(color: tint.opacity(isFocused ? 0.3 : 0.1), radius: isFocused ? 16 : 8, y: 4)
    }
}

// MARK: - Glass Badge

struct LiquidGlassBadge: View {
    let text: String
    let icon: String?
    let tint: Color

    init(
        _ text: String,
        icon: String? = nil,
        tint: Color = .white
    ) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(tint.opacity(0.15))
                Capsule()
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: tint.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Dark background
        Color.black.ignoresSafeArea()

        VStack(spacing: 32) {
            // Cards
            LiquidGlassCard(tint: .cyan) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Liquid Glass Card")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Beautiful frosted glass effect with depth and dimension")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Buttons
            HStack(spacing: 16) {
                LiquidGlassButton("Action", icon: "paperplane.fill", tint: .cyan) {}
                LiquidGlassButton("Cancel", tint: .red) {}
            }

            // FAB
            LiquidGlassFAB(icon: "plus", tint: .cyan) {}

            // Text Field
            LiquidGlassTextField("Enter message", text: .constant(""), tint: .cyan)

            // Badges
            HStack(spacing: 12) {
                LiquidGlassBadge("Swift", icon: "swift", tint: .orange)
                LiquidGlassBadge("Active", icon: "circle.fill", tint: .green)
                LiquidGlassBadge("< 10m", tint: .cyan)
            }
        }
        .padding(24)
    }
}
