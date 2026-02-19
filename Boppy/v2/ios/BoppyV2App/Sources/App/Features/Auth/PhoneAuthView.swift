import SwiftUI
import UIKit

struct PhoneAuthView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var selectedCountry = CountryCode.us
    @State private var phoneLocal = ""
    @State private var code = ""
    @State private var codeRequested = false
    @State private var isSubmitting = false
    @ScaledMetric(relativeTo: .title) private var brandSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var authCardPadding: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var continueButtonVerticalPadding: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var trustStripHorizontalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var trustStripVerticalPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var headerOuterSize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var headerInnerSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var headerGlyphSize: CGFloat = 22

    var body: some View {
        authV2
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenBackground()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var authV2: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer(minLength: 28)

                    VStack(spacing: 16) {
                        headerIcon

                        VStack(spacing: 6) {
                            Text("boppyv1")
                                .font(AppTheme.inter(brandSize, weight: .bold, relativeTo: .largeTitle))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Secure phone verification")
                                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium, relativeTo: .subheadline))
                                .foregroundStyle(AppTheme.textMuted)
                        }

                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Picker("Country", selection: $selectedCountry) {
                                    ForEach(CountryCode.allCases, id: \.self) { country in
                                        Text("\(country.flag) \(country.dialCode)").tag(country)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 110)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                        .fill(AppTheme.surfaceElevated)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                                .accessibilityLabel("Country code")
                                .accessibilityHint("Select your phone country code.")
                                .accessibilityIdentifier("auth.countryCode")

                                InputTextField(
                                    placeholder: "Phone number",
                                    text: $phoneLocal,
                                    keyboardType: .phonePad,
                                    disableActions: true
                                )
                                .frame(height: 48)
                                .accessibilityLabel("Phone number")
                                .accessibilityHint("Enter your phone number to receive a verification code.")
                                .accessibilityIdentifier("auth.phoneNumber")
                            }

                            if codeRequested {
                                InputTextField(
                                    placeholder: "6-digit code",
                                    text: $code,
                                    keyboardType: .numberPad,
                                    disableActions: true
                                )
                                .frame(height: 48)
                                .accessibilityLabel("Verification code")
                                .accessibilityHint("Enter the 6 digit code sent to your phone.")
                                .accessibilityIdentifier("auth.code")
                            }
                        }

                        if coordinator.featureFlags.showDemoAuthShortcuts {
                            VStack(spacing: 8) {
                                roleButton(
                                    title: "Continue as Owner",
                                    subtitle: "+15550000001",
                                    icon: "person.crop.circle.badge.checkmark",
                                    identifier: "auth.continueOwner",
                                    action: { signInDemo(phone: "+15550000001") }
                                )
                                roleButton(
                                    title: "Continue as Driver",
                                    subtitle: "+15550000002",
                                    icon: "steeringwheel",
                                    identifier: "auth.continueDriver",
                                    action: { signInDemo(phone: "+15550000002") }
                                )
                                roleButton(
                                    title: "Continue as Follower",
                                    subtitle: "+15550000003",
                                    icon: "person.2.fill",
                                    identifier: "auth.continueFollower",
                                    action: { signInDemo(phone: "+15550000003") }
                                )
                            }
                        }

                        Button {
                            Task {
                                isSubmitting = true
                                defer { isSubmitting = false }
                                if codeRequested {
                                    await coordinator.verifyOTP(phone: resolvedPhone, code: code)
                                } else {
                                    await coordinator.requestOTP(phone: resolvedPhone)
                                    codeRequested = true
                                    if coordinator.featureFlags.motionV2 {
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(AppTheme.textPrimary)
                                        .scaleEffect(0.8)
                                } else {
                                    Text(codeRequested ? "Continue" : "Send Code")
                                        .font(AppTheme.inter(AppTheme.typeBody, weight: .semibold, relativeTo: .headline))
                                    DesignIconView(icon: .chevronRight, size: 14, color: AppTheme.textPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, continueButtonVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                    .fill(AppTheme.accentBlue)
                            )
                            .foregroundStyle(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)
                        .accessibilityLabel(codeRequested ? "Verify code" : "Send code")
                        .accessibilityHint(codeRequested ? "Verifies your one-time passcode and signs you in." : "Sends a one-time passcode to your phone.")
                        .accessibilityIdentifier(codeRequested ? "auth.verifyCode" : "auth.sendCode")

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                            Text("Invite-only network. Contact your supplier for access.")
                        }
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.accentBlue)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .fill(AppTheme.accentBlue.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .stroke(AppTheme.accentBlue.opacity(0.12), lineWidth: 1)
                        )
                        .accessibilityLabel("Invite-only access info")
                        .accessibilityHint("Explains how to request boppyv1 access.")
                        .accessibilityIdentifier("auth.inviteInfo")
                    }
                    .padding(authCardPadding)
                    .frame(maxWidth: 420)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous)
                            .fill(AppTheme.cardGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("auth.card")

                    trustStrip
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var headerIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous)
                .fill(AppTheme.accentBlue.opacity(0.2))
                .frame(width: headerOuterSize, height: headerOuterSize)
            Circle()
                .fill(AppTheme.accentBlue)
                .frame(width: headerInnerSize, height: headerInnerSize)
                .overlay {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: headerGlyphSize, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
        }
        .accessibilityHidden(true)
    }

    private var trustStrip: some View {
        HStack(spacing: 8) {
            Text("ENCRYPTED")
            Text("/")
            Text("VERIFIED")
            Text("/")
            Text("BOPPYV1")
        }
        .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold, relativeTo: .caption))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.horizontal, trustStripHorizontalPadding)
        .padding(.vertical, trustStripVerticalPadding)
        .background(
            Capsule()
                .fill(AppTheme.surfaceCardSecondary)
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Security trust strip")
        .accessibilityValue("Encrypted, verified, boppyv1 version 2.0.4")
        .accessibilityIdentifier("auth.trustStrip")
    }

    private var resolvedPhone: String {
        let digits = phoneLocal
            .filter { $0.isNumber }
        return "\(selectedCountry.dialCode)\(digits)"
    }

    private func roleButton(title: String, subtitle: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.accentBlueSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                DesignIconView(icon: .chevronRight, size: 12, color: AppTheme.accentBlue)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.accentBlue.opacity(0.14), in: Circle())
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(AppTheme.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Signs in with a demo role shortcut.")
        .accessibilityIdentifier(identifier)
    }

    private func signInDemo(phone: String) {
        Task {
            await coordinator.requestOTP(phone: phone)
            await coordinator.verifyOTP(phone: phone, code: "123456")
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum CountryCode: CaseIterable {
    case us
    case ae
    case gb

    var flag: String {
        switch self {
        case .us: return "🇺🇸"
        case .ae: return "🇦🇪"
        case .gb: return "🇬🇧"
        }
    }

    var dialCode: String {
        switch self {
        case .us: return "+1"
        case .ae: return "+971"
        case .gb: return "+44"
        }
    }
}

private struct InputTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let disableActions: Bool

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: InputTextField

        init(parent: InputTextField) {
            self.parent = parent
        }

        @objc func didChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = disableActions ? NoActionTextField() : UITextField()
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        field.textContentType = nil
        field.autocapitalizationType = .none
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.didChange(_:)), for: .editingChanged)

        field.backgroundColor = UIColor(AppTheme.surfaceElevated)
        field.textColor = UIColor(AppTheme.textPrimary)
        field.tintColor = UIColor(AppTheme.accentBlue)
        field.layer.cornerRadius = AppTheme.radiusMedium
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor(AppTheme.border).cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always

        if let placeholder = field.placeholder {
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor(AppTheme.textMuted)]
            )
        }

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}

private final class NoActionTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}
