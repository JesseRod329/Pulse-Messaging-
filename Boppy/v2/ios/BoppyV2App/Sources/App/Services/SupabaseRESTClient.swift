import Foundation

enum SupabaseClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String)
    case decoding(Error)
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .invalidResponse:
            return "Invalid backend response."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case let .server(_, message):
            return message
        case let .decoding(error):
            return "Response decode failed: \(error.localizedDescription)"
        case .missingSession:
            return "No active session available."
        }
    }
}

private struct EdgeEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: EdgeErrorPayload?
    let request_id: String
}

private struct EdgeErrorPayload: Decodable {
    let code: String
    let message: String
}

struct AuthVerifyResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let user: AuthUser
}

struct AuthRefreshResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let user: AuthUser?
}

struct AuthUser: Decodable {
    let id: String
    let phone: String?
}

final class SupabaseRESTClient {
    private let config: SupabaseConfig
    private let session: URLSession
    private let tokenStore: SessionTokenStore

    init(
        config: SupabaseConfig,
        session: URLSession? = nil,
        tokenStore: SessionTokenStore = MigratingSessionTokenStore()
    ) {
        self.config = config
        self.session = session ?? Self.configuredSession()
        self.tokenStore = tokenStore
    }

    func requestOTP(phoneE164: String) async throws {
        let payload: [String: Any] = [
            "phone": phoneE164,
            "create_user": true
        ]
        _ = try await authRequest(path: "/auth/v1/otp", method: "POST", body: payload)
    }

    func verifyOTP(phoneE164: String, code: String) async throws -> AuthVerifyResponse {
        let payload: [String: Any] = [
            "phone": phoneE164,
            "token": code,
            "type": "sms"
        ]

        let data = try await authRequest(path: "/auth/v1/verify", method: "POST", body: payload)
        do {
            return try JSONDecoder.iso8601.decode(AuthVerifyResponse.self, from: data)
        } catch {
            throw SupabaseClientError.decoding(error)
        }
    }

    func refreshSession(refreshToken: String) async throws -> AuthRefreshResponse {
        let payload: [String: Any] = [
            "refresh_token": refreshToken
        ]

        let data = try await authRequest(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: payload
        )
        do {
            return try JSONDecoder.iso8601.decode(AuthRefreshResponse.self, from: data)
        } catch {
            throw SupabaseClientError.decoding(error)
        }
    }

    func fetchAuthUser(accessToken: String) async throws -> AuthUser {
        try await executeWithRefreshRetry(initialAccessToken: accessToken) { token in
            let data = try await self.authRequest(path: "/auth/v1/user", method: "GET", body: nil, accessToken: token)
            do {
                return try JSONDecoder.iso8601.decode(AuthUser.self, from: data)
            } catch {
                throw SupabaseClientError.decoding(error)
            }
        }
    }

    func restGet(pathAndQuery: String, accessToken: String) async throws -> Data {
        try await restRequest(pathAndQuery: pathAndQuery, method: "GET", body: nil, accessToken: accessToken)
    }

    func restPost(pathAndQuery: String, body: Any, accessToken: String, prefer: String? = nil) async throws -> Data {
        try await restRequest(pathAndQuery: pathAndQuery, method: "POST", body: body, accessToken: accessToken, prefer: prefer)
    }

    func restPatch(pathAndQuery: String, body: Any, accessToken: String, prefer: String? = nil) async throws -> Data {
        try await restRequest(pathAndQuery: pathAndQuery, method: "PATCH", body: body, accessToken: accessToken, prefer: prefer)
    }

    /// Uploads raw file data to Supabase Storage and returns the public URL string.
    func storageUpload(
        bucket: String,
        path: String,
        data: Data,
        contentType: String,
        accessToken: String
    ) async throws -> String {
        try await executeWithRefreshRetry(initialAccessToken: accessToken) { token in
            guard let url = URL(
                string: "\(self.config.url.absoluteString)/storage/v1/object/\(bucket)/\(path)"
            ) else {
                throw SupabaseClientError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue(self.config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")

            let (responseData, response) = try await self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                throw self.decodeError(status: status, data: responseData)
            }

            return "\(self.config.url.absoluteString)/storage/v1/object/public/\(bucket)/\(path)"
        }
    }

    func edgeCall<T: Decodable>(
        functionName: String,
        accessToken: String,
        body: Any
    ) async throws -> T {
        try await executeWithRefreshRetry(initialAccessToken: accessToken) { token in
            let url = self.config.edgeBaseURL.appendingPathComponent(functionName)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(self.config.anonKey, forHTTPHeaderField: "apikey")

            let (data, response) = try await self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                throw self.decodeError(status: status, data: data)
            }

            do {
                let envelope = try JSONDecoder.iso8601.decode(EdgeEnvelope<T>.self, from: data)
                if envelope.success, let payload = envelope.data {
                    return payload
                }
                throw SupabaseClientError.server(status: status, message: envelope.error?.message ?? "Function call failed")
            } catch let error as SupabaseClientError {
                throw error
            } catch {
                throw SupabaseClientError.decoding(error)
            }
        }
    }

    private func authRequest(path: String, method: String, body: Any?, accessToken: String? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: config.url) else {
            throw SupabaseClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw decodeError(status: status, data: data)
        }

        return data
    }

    private func restRequest(pathAndQuery: String, method: String, body: Any?, accessToken: String, prefer: String? = nil) async throws -> Data {
        try await executeWithRefreshRetry(initialAccessToken: accessToken) { token in
            guard let url = URL(string: "/rest/v1/\(pathAndQuery)", relativeTo: self.config.url) else {
                throw SupabaseClientError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue(self.config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let prefer {
                request.setValue(prefer, forHTTPHeaderField: "Prefer")
            }
            if let body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                throw self.decodeError(status: status, data: data)
            }

            return data
        }
    }

    private func decodeError(status: Int, data: Data) -> SupabaseClientError {
        if status == 401 {
            return .unauthorized
        }

        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String {
            return .server(status: status, message: message)
        }

        let text = String(data: data, encoding: .utf8) ?? "Request failed with status \(status)"
        return .server(status: status, message: text)
    }

    private func executeWithRefreshRetry<T>(
        initialAccessToken: String,
        operation: (String) async throws -> T
    ) async throws -> T {
        let accessToken = tokenStore.readTokens()?.accessToken ?? initialAccessToken

        do {
            return try await operation(accessToken)
        } catch let error as SupabaseClientError {
            guard case .unauthorized = error else {
                throw error
            }

            guard let refreshedAccessToken = try await refreshAccessTokenIfPossible() else {
                throw error
            }

            return try await operation(refreshedAccessToken)
        }
    }

    private func refreshAccessTokenIfPossible() async throws -> String? {
        guard
            let existing = tokenStore.readTokens(),
            let refreshToken = existing.refreshToken,
            !refreshToken.isEmpty
        else {
            return nil
        }

        let refreshed = try await refreshSession(refreshToken: refreshToken)
        let merged = SessionTokens(
            accessToken: refreshed.access_token,
            refreshToken: refreshed.refresh_token ?? existing.refreshToken,
            userID: refreshed.user?.id ?? existing.userID,
            userPhone: refreshed.user?.phone ?? existing.userPhone
        )
        tokenStore.saveTokens(merged)
        return merged.accessToken
    }

    private static func configuredSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }
}
