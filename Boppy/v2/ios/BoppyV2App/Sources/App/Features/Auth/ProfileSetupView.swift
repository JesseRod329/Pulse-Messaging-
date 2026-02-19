import SwiftUI
import BoppyV2Core

struct ProfileSetupView: View {
    let role: UserRole
    let onComplete: (String) -> Void

    @State private var displayName = ""
    @FocusState private var nameFocused: Bool

    private var roleLabel: String {
        switch role {
        case .driver: return "Driver"
        case .follower: return "Member"
        case .owner: return "Owner"
        }
    }

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Branding / icon
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentBlue.opacity(0.18))
                                .frame(width: 80, height: 80)
                            Image(systemName: role == .driver ? "car.fill" : "person.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AppTheme.accentBlue)
                        }

                        Text("Welcome to Beamly")
                            .font(AppTheme.inter(AppTheme.typeTitle2, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("You're joining as a \(roleLabel). What should we call you?")
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .regular, relativeTo: .subheadline))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your name")
                            .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(AppTheme.textSecondary)

                        TextField("Enter your name", text: $displayName)
                            .feedInputFieldStyle()
                            .focused($nameFocused)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .onSubmit {
                                if canContinue { submit() }
                            }
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            submit()
                        } label: {
                            Text("Get Started")
                                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
                        .padding(.horizontal, AppTheme.screenHorizontalPadding)

                        Button {
                            onComplete(roleLabel)
                        } label: {
                            Text("Skip for now")
                                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .footnote))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFocused = true
            }
        }
    }

    private func submit() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onComplete(name)
    }
}
