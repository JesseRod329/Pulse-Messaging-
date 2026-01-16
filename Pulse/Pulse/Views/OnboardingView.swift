//
//  OnboardingView.swift
//  Pulse
//
//  A clean, minimal onboarding experience inspired by Apple and Anthropic.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var handle = ""
    @State private var selectedTechStack: Set<String> = []
    @State private var showContent = false
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.white : Color.white.opacity(0.2))
                            .frame(width: index == currentStep ? 24 : 8, height: 4)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)

                Spacer()

                // Content
                SwiftUI.Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        HandleStep(handle: $handle)
                    case 2:
                        TechStackStep(selectedTech: $selectedTechStack)
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Bottom button
                Button(action: nextStep) {
                    HStack(spacing: 8) {
                        Text(buttonText)
                            .font(.body)
                            .fontWeight(.semibold)

                        if currentStep == 2 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(canProceed ? .black : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canProceed ? Color.white : Color.white.opacity(0.1))
                    )
                }
                .disabled(!canProceed || isTransitioning)
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .animation(.easeInOut(duration: 0.2), value: canProceed)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                .accessibilityLabel(buttonText)
                .accessibilityHint(currentStep == 2 ? "Completes setup and starts discovering developers" : "Continues to next step")
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
        }
    }

    private var buttonText: String {
        switch currentStep {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return "Start Discovering"
        default: return "Continue"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return isValidHandle
        case 2: return !selectedTechStack.isEmpty
        default: return true
        }
    }

    private var isValidHandle: Bool {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    private func nextStep() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        isTransitioning = true

        if currentStep < 2 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isTransitioning = false
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Create cryptographic identity
        _ = IdentityManager.shared.createIdentity(handle: handle)

        // Save preferences
        UserDefaults.standard.set(handle, forKey: "handle")
        UserDefaults.standard.set(Array(selectedTechStack), forKey: "techStack")
        UserDefaults.standard.set(PeerStatus.active.rawValue, forKey: "userStatus")

        onComplete()
    }
}

// MARK: - Step Views

struct WelcomeStep: View {
    @State private var isPulsing = false
    @State private var showRings = false
    @State private var iconScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            // Animated pulse icon
            ZStack {
                // Outer pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(showRings ? 0 : 0.3), lineWidth: 1)
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(showRings ? 1.5 : 1)
                        .opacity(showRings ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                            value: showRings
                        )
                }

                // Core icon with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isPulsing
                        )

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white)
                        .scaleEffect(iconScale)
                }
            }
            .frame(height: 200)

            VStack(spacing: 16) {
                Text("Pulse")
                    .font(.pulseDisplay)
                    .foregroundStyle(.white)
                    .opacity(textOpacity)

                Text("Discover developers around you.\nConnect. Collaborate. Code.")
                    .font(.pulseBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(textOpacity)
            }
        }
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to Pulse. Discover developers around you. Connect. Collaborate. Code.")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPulsing = true
                showRings = true
            }
        }
    }
}

struct HandleStep: View {
    @Binding var handle: String
    @FocusState private var isFocused: Bool
    @State private var showContent = false

    private var isValid: Bool {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    private var validationMessage: String {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "At least 2 characters"
        } else if trimmed.count < 2 {
            return "\(2 - trimmed.count) more character\(trimmed.count == 1 ? "" : "s") needed"
        } else if trimmed.count > 20 {
            return "Too long"
        } else {
            return "Looks good!"
        }
    }

    private var validationColor: Color {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .white.opacity(0.3)
        } else if trimmed.count < 2 || trimmed.count > 20 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Choose your handle")
                    .font(.pulsePageTitle)
                    .foregroundStyle(.white)

                Text("This is how other developers will see you")
                    .font(.pulseBodySecondary)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)

            VStack(spacing: 12) {
                // Handle input
                HStack(spacing: 4) {
                    Text("@")
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField("", text: $handle, prompt: Text("your_handle").foregroundStyle(.white.opacity(0.2)))
                        .font(.sfMono(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .onChange(of: handle) { _, newValue in
                            // Filter to valid characters
                            let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue {
                                handle = filtered
                            }
                        }

                    if !handle.isEmpty {
                        Button(action: { handle = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .accessibilityLabel("Clear handle")
                        .accessibilityHint("Clears the entered handle")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isFocused ? validationColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                )

                // Validation feedback
                HStack {
                    HStack(spacing: 6) {
                        if isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                        }
                        Text(validationMessage)
                            .font(.pulseCaption)
                    }
                    .foregroundStyle(validationColor)

                    Spacer()

                    Text("\(handle.count)/20")
                        .font(.pulseTimestamp)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 8)
                .animation(.easeInOut(duration: 0.15), value: handle)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

struct TechStackStep: View {
    @Binding var selectedTech: Set<String>
    @State private var showContent = false

    let technologies: [(name: String, icon: String, color: Color)] = [
        ("Swift", "swift", .orange),
        ("Python", "chevron.left.forwardslash.chevron.right", .blue),
        ("JavaScript", "curlybraces", .yellow),
        ("TypeScript", "t.square", .blue),
        ("Rust", "gearshape.2", .orange),
        ("Go", "hare", .cyan),
        ("Kotlin", "k.circle", .purple),
        ("Java", "cup.and.saucer", .red),
        ("C++", "memorychip", .blue),
        ("Ruby", "diamond", .red),
        ("PHP", "server.rack", .indigo),
        ("C#", "number", .purple)
    ]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What do you work with?")
                    .font(.pulsePageTitle)
                    .foregroundStyle(.white)

                Text("Select your primary technologies")
                    .font(.pulseBodySecondary)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)

            // Selection count
            if !selectedTech.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("\(selectedTech.count) selected")
                        .font(.pulseLabel)
                }
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
            }

            // Tech grid - scrollable for more options
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(technologies.enumerated()), id: \.element.name) { index, tech in
                        TechButton(
                            title: tech.name,
                            icon: tech.icon,
                            accentColor: tech.color,
                            isSelected: selectedTech.contains(tech.name)
                        ) {
                            // Haptic feedback
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()

                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                if selectedTech.contains(tech.name) {
                                    selectedTech.remove(tech.name)
                                } else {
                                    selectedTech.insert(tech.name)
                                }
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.03), value: showContent)
                        .accessibilityLabel(tech.name)
                        .accessibilityValue(selectedTech.contains(tech.name) ? "Selected" : "Not selected")
                        .accessibilityHint("Double tap to \(selectedTech.contains(tech.name) ? "deselect" : "select")")
                        .accessibilityAddTraits(selectedTech.contains(tech.name) ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 320)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
}

struct TechButton: View {
    let title: String
    let icon: String
    var accentColor: Color = .white
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .black : accentColor)
                    .frame(width: 20)

                Text(title)
                    .font(.pulseLabel)
                    .foregroundStyle(isSelected ? .black : .white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
