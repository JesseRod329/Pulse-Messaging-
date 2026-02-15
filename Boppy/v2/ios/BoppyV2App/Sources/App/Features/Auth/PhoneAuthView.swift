import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var phone = "+1555"
    @State private var code = ""
    @State private var codeRequested = false

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Sign In")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(AppTheme.accentBlue)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Image(systemName: AppTheme.brandSymbolName)
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BeamBox V2")
                                            .font(AppTheme.titleFont)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(coordinator.isDemoMode ? "Demo authentication flow" : "Live OTP authentication flow")
                                            .font(AppTheme.captionFont)
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                }

                                Text(authSubtitle)
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }

                            if coordinator.isDemoMode {
                                VStack(spacing: 10) {
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
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    InputTextField(
                                        placeholder: "+15551234567",
                                        text: $phone,
                                        keyboardType: .phonePad,
                                        disableActions: true
                                    )
                                    .frame(height: 48)

                                    if codeRequested {
                                        InputTextField(
                                            placeholder: "6-digit code",
                                            text: $code,
                                            keyboardType: .numberPad,
                                            disableActions: true
                                        )
                                        .frame(height: 48)

                                        Button("Verify Code") {
                                            Task {
                                                await coordinator.verifyOTP(phone: phone, code: code)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(AppTheme.accentBlue)
                                        .frame(maxWidth: .infinity)
                                        .accessibilityIdentifier("auth.verifyCode")
                                    }

                                    Button(codeRequested ? "Resend Code" : "Send Code") {
                                        Task {
                                            await coordinator.requestOTP(phone: phone)
                                            codeRequested = true
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(AppTheme.accentBlue)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityIdentifier("auth.sendCode")
                                }
                            }
                        }
                        .padding(AppTheme.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius + 2, style: .continuous)
                                .fill(AppTheme.cardGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius + 2, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.top, max(proxy.safeAreaInsets.top + 8, 22))
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenBackground()
    }

    private func roleButton(title: String, subtitle: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(AppTheme.accentBlueSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentBlue)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.accentBlue.opacity(0.14), in: Circle())
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var authSubtitle: String {
        if coordinator.isDemoMode {
            return "Choose a role shortcut to preview owner, driver, or follower surfaces."
        }
        return "Use your phone number to receive an OTP code via Supabase + Twilio."
    }

    private func signInDemo(phone: String) {
        Task {
            await coordinator.requestOTP(phone: phone)
            await coordinator.verifyOTP(phone: phone, code: "123456")
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
        field.layer.cornerRadius = 12
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
