import Foundation

/// Every failure the app can surface to the user. Mapped to copy in `ErrorMessageMapper`.
nonisolated enum AppError: Error, Equatable, Sendable {
    /// Reserved for a provider reporting that the user backed out (Cognito / `ASAuthorizationError.canceled`);
    /// task cancellation is handled quietly in `SessionController` and never reaches the popup.
    case authCancelled
    case authFailed(provider: AuthProvider.Kind)
    /// Apple and Google stay on the sheet but have no identity provider in the pool yet.
    case providerUnavailable(provider: AuthProvider.Kind)
    case invalidCredentials
    case emailTaken
    /// The account exists but the emailed code was never entered; the form offers the code step, no popup.
    case emailNotConfirmed
    case invalidConfirmationCode
    case tooManyAttempts
    /// The backend rejected the token (401), or Amplify could not refresh it.
    case sessionExpired
    case network
    case eventsUnavailable
    case eventNotFound
    case eventFull
    case alreadyJoined
    case notAParticipant
    case hostCannotLeave
    case tryAgain
    /// A join or leave failed for a reason without copy of its own (a 500, an unreadable body).
    case participationFailed
    /// Creating an event failed for a reason without copy of its own (a 500, a validation the form did not catch).
    case eventCreationFailed
    case unknown

    /// Normalises any thrown error into an `AppError`.
    static func wrapping(_ error: any Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is CancellationError { return .authCancelled }
        if (error as? URLError) != nil { return .network }
        return .unknown
    }

    /// The caller left mid-request (screen dismissed, task cancelled): not a failure, never shown.
    static func isCancellation(_ error: any Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
