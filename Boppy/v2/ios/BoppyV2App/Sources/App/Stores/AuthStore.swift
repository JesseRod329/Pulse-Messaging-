import Foundation
import BoppyV2Core

@MainActor
final class AuthStore: ObservableObject {
    @Published var user: SessionUser?
    @Published var inviteTokenInput: String = ""
    @Published var latestInvite: ChannelInvite?
    @Published var isLoading: Bool = false
    @Published var appError: AppError?
    @Published var errorMessage: String?
    @Published var isOffline: Bool = false

    func present(_ appError: AppError, fallbackMessage: String? = nil) {
        self.appError = appError
        errorMessage = appError.errorDescription ?? fallbackMessage ?? "Something went wrong."
    }

    func clearPresentedError() {
        appError = nil
        errorMessage = nil
    }

    func bootstrapSession(authService: AuthServiceProtocol) async throws {
        user = try await authService.currentSession()
    }

    func requestOTP(
        phone: String,
        authService: AuthServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) async throws {
        try await authService.requestOTP(phoneE164: phone)
        analyticsService.track(event: "otp_requested", properties: ["phone": phone])
    }

    @discardableResult
    func verifyOTP(
        phone: String,
        code: String,
        authService: AuthServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) async throws -> SessionUser {
        let session = try await authService.verifyOTP(phoneE164: phone, code: code)
        user = session
        analyticsService.track(event: "otp_verified", properties: ["role": session.role.rawValue])
        return session
    }

    func applySignOutState(preserveError: Bool) {
        user = nil
        inviteTokenInput = ""
        latestInvite = nil
        isLoading = false
        isOffline = false
        if !preserveError {
            clearPresentedError()
        }
    }
}
