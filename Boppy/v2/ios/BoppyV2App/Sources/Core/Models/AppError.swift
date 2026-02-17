import Foundation

public enum AuthFailure: Equatable {
    case unauthorized
    case forbidden
    case missingSession
    case sessionExpired
}

public enum AppError: LocalizedError, Equatable {
    case network(URLError)
    case auth(AuthFailure)
    case validation(String)
    case backend(statusCode: Int, message: String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .network:
            return "Network request failed. Check your connection and try again."
        case let .auth(reason):
            switch reason {
            case .unauthorized, .sessionExpired:
                return "Session expired. Please sign in again."
            case .forbidden:
                return "You do not have permission to perform this action."
            case .missingSession:
                return "No active session is available."
            }
        case let .validation(message):
            return message
        case let .backend(_, message):
            return message
        case let .unknown(message):
            return message
        }
    }

    public static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let urlError = error as? URLError {
            return .network(urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(URLError(URLError.Code(rawValue: nsError.code)))
        }

        return .unknown(error.localizedDescription)
    }
}
