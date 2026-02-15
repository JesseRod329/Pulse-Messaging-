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

struct AuthUser: Decodable {
    let id: String
    let phone: String?
}

final class SupabaseRESTClient {
    private let config: SupabaseConfig
    private let session: URLSession

    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
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

    func fetchAuthUser(accessToken: String) async throws -> AuthUser {
        let data = try await authRequest(path: "/auth/v1/user", method: "GET", body: nil, accessToken: accessToken)
        do {
            return try JSONDecoder.iso8601.decode(AuthUser.self, from: data)
        } catch {
            throw SupabaseClientError.decoding(error)
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

    func edgeCall<T: Decodable>(
        functionName: String,
        accessToken: String,
        body: Any
    ) async throws -> T {
        let url = config.edgeBaseURL.appendingPathComponent(functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw try decodeError(status: status, data: data)
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
            throw try decodeError(status: status, data: data)
        }

        return data
    }

    private func restRequest(pathAndQuery: String, method: String, body: Any?, accessToken: String, prefer: String? = nil) async throws -> Data {
        guard let url = URL(string: "/rest/v1/\(pathAndQuery)", relativeTo: config.url) else {
            throw SupabaseClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw try decodeError(status: status, data: data)
        }

        return data
    }

    private func decodeError(status: Int, data: Data) throws -> SupabaseClientError {
        if status == 401 || status == 403 {
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
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
