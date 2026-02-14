import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var phone = "+1555"
    @State private var code = ""
    @State private var codeRequested = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BeamBox V2")
                            .font(.title.bold())
                        Text(authSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    TextField("+15551234567", text: $phone)
                        .textInputAutocapitalization(.never)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)

                    if codeRequested {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)

                        Button("Verify Code") {
                            Task {
                                await coordinator.verifyOTP(phone: phone, code: code)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(codeRequested ? "Resend Code" : "Send Code") {
                        Task {
                            await coordinator.requestOTP(phone: phone)
                            codeRequested = true
                        }
                    }
                    .buttonStyle(.bordered)

                    if coordinator.isDemoMode {
                        Divider().padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Demo accounts")
                                .font(.headline)
                            Text("Owner: +15550000001")
                            Text("Driver: +15550000002")
                            Text("Follower: any other phone")
                            Text("Demo OTP: 123456")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(16)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var authSubtitle: String {
        if coordinator.isDemoMode {
            return "Demo mode is active. OTP runs against local in-memory services."
        }
        return "Live mode is active. OTP runs through Supabase Auth + Twilio SMS."
    }
}
