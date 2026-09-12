import Foundation

/// Backend error codes with user-facing copy of their own. Anything else falls back to the caller's generic error.
nonisolated enum BackendErrorCode: String, Sendable {
    case eventNotFound = "EVENT_NOT_FOUND"
    case eventFull = "EVENT_FULL"
    case alreadyJoined = "ALREADY_JOINED"
    case notAParticipant = "NOT_A_PARTICIPANT"
    case hostCannotLeave = "HOST_CANNOT_LEAVE"
    /// A join or leave lost a race with another player or was throttled; repeating it is safe.
    case tryAgain = "TRY_AGAIN"

    var appError: AppError {
        switch self {
        case .eventNotFound: .eventNotFound
        case .eventFull: .eventFull
        case .alreadyJoined: .alreadyJoined
        case .notAParticipant: .notAParticipant
        case .hostCannotLeave: .hostCannotLeave
        case .tryAgain: .tryAgain
        }
    }
}

extension APIError {
    /// A known backend code becomes its own case; every other API failure becomes `fallback`.
    func appError(fallback: AppError) -> AppError {
        guard case .http(_, let body) = self, let body, let code = BackendErrorCode(rawValue: body.code) else {
            return fallback
        }
        return code.appError
    }
}

extension APIClient {
    /// `send` for callers that show failures: known backend codes map to their `AppError`, transport failures to
    /// `.network`, everything else to `fallback`. Cancellation passes through unchanged so screens can stay quiet.
    func send<Response: Decodable>(_ request: APIRequest<Response>, failingWith fallback: AppError) async throws -> Response {
        do {
            return try await send(request)
        } catch let error as APIError {
            throw error.appError(fallback: fallback)
        } catch let error as URLError where error.code != .cancelled {
            throw AppError.network
        }
    }
}
