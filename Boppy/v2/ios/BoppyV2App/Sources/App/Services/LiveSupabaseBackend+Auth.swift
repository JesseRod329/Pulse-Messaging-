import Foundation
import BoppyV2Core

extension LiveSupabaseBackend {
    // MARK: - Auth

    func requestOTP(phoneE164: String) async throws {
        try await client.requestOTP(phoneE164: phoneE164)
    }

    func verifyOTP(phoneE164: String, code: String) async throws -> SessionUser {
        let response = try await client.verifyOTP(phoneE164: phoneE164, code: code)
        sessionStore.saveTokens(
            SessionTokens(
                accessToken: response.access_token,
                refreshToken: response.refresh_token,
                userID: response.user.id,
                userPhone: response.user.phone
            )
        )

        try await upsertProfile(
            userID: response.user.id,
            phoneE164: response.user.phone ?? phoneE164,
            displayName: nil,
            accessToken: response.access_token
        )

        let sessionUser = try await resolveSessionUser(
            userID: response.user.id,
            fallbackPhone: response.user.phone ?? phoneE164,
            accessToken: response.access_token
        )
        await writeCachedSession(sessionUser)
        analytics.track(event: "live_auth_verify", properties: ["role": sessionUser.role.rawValue])
        return sessionUser
    }

    func currentSession() async throws -> SessionUser? {
        if let cachedSession = await readCachedSession() {
            return cachedSession
        }

        guard let tokens = sessionStore.readTokens() else {
            return nil
        }

        do {
            let authUser = try await client.fetchAuthUser(accessToken: tokens.accessToken)
            let sessionUser = try await resolveSessionUser(
                userID: tokens.userID,
                fallbackPhone: authUser.phone ?? tokens.userPhone ?? "+10000000000",
                accessToken: tokens.accessToken
            )
            await writeCachedSession(sessionUser)
            return sessionUser
        } catch {
            sessionStore.clearTokens()
            await writeCachedSession(nil)
            return nil
        }
    }

    func signOut() async {
        await writeCachedSession(nil)
        sessionStore.clearTokens()
    }

    private func readCachedSession() async -> SessionUser? {
        await sessionState.read()
    }

    private func writeCachedSession(_ session: SessionUser?) async {
        await sessionState.write(session)
    }


}
