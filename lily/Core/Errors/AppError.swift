import Foundation

/// Every failure the app can surface to the user. Mapped to copy in `ErrorMessageMapper`.
nonisolated enum AppError: Error, Equatable, Sendable {
    /// Reserved for a provider reporting that the user backed out (Cognito / `ASAuthorizationError.canceled`);
    /// task cancellation is handled quietly in `SessionController` and never reaches the popup.
    case authCancelled
    case authFailed(provider: AuthProvider.Kind)
    case invalidCredentials
    case sessionExpired
    case network
    case eventsUnavailable
    case unknown

    /// Normalises any thrown error into an `AppError`.
    static func wrapping(_ error: any Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is CancellationError { return .authCancelled }
        if (error as? URLError) != nil { return .network }
        return .unknown
    }
}
