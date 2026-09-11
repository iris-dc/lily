import Foundation
import Observation

/// Owns the session state machine. Views read `state`; all mutations go through the methods below.
@Observable
final class SessionController {
    private(set) var state: SessionState = .loading
    /// Provider currently mid sign-in, so buttons can show a spinner without a second source of truth.
    private(set) var authenticatingProvider: AuthProvider.Kind?
    private var isSigningOut = false

    private let authService: any AuthService
    private let sessionStore: any SessionStore
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(authService: any AuthService,
         sessionStore: any SessionStore,
         errorCenter: ErrorCenter,
         logger: any Logging) {
        self.authService = authService
        self.sessionStore = sessionStore
        self.errorCenter = errorCenter
        self.logger = logger
    }

    func restore() async {
        do {
            if let session = try await authService.restoreSession() {
                logger.info(.auth, "Session restored for user \(session.user.id)")
                state = .signedIn(session.user)
                return
            }
        } catch {
            logger.warning(.auth, "Session restore failed: \(error)")
        }
        if sessionStore.load() == .guest {
            logger.info(.auth, "Restored guest mode")
            state = .guest
        } else {
            logger.info(.auth, "No stored session")
            state = .signedOut
        }
    }

    /// Returns `true` on success. Failures are reported through the shared error popup.
    @discardableResult
    func signIn(with provider: AuthProvider) async -> Bool {
        guard beginAuthenticating(provider.kind) else { return false }
        defer { authenticatingProvider = nil }
        return await performSignIn(with: provider)
    }

    /// Holds the authentication slot for the whole sign-up, so a provider tap cannot interleave with it.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        guard beginAuthenticating(.email) else { return false }
        defer { authenticatingProvider = nil }
        do {
            try await authService.signUp(email: email, password: password)
            logger.info(.auth, "Sign-up succeeded")
            return await performSignIn(with: .email(EmailCredentials(email: email, password: password)))
        } catch is CancellationError {
            logger.info(.auth, "Sign-up cancelled")
            return false
        } catch {
            logger.error(.auth, "Sign-up failed: \(error)")
            errorCenter.report(error)
            return false
        }
    }

    func continueAsGuest() {
        logger.info(.auth, "Continuing as guest")
        sessionStore.save(.guest)
        state = .guest
    }

    /// Clears the local session before the remote call, so a late duplicate cannot undo a choice made meanwhile.
    func signOut() async {
        guard !isSigningOut else {
            logger.debug(.auth, "Ignored sign-out: another sign-out is in progress")
            return
        }
        isSigningOut = true
        defer { isSigningOut = false }
        sessionStore.clear()
        state = .signedOut
        logger.info(.auth, "Signed out")
        do {
            try await authService.signOut()
        } catch {
            logger.warning(.auth, "Remote sign-out failed, local session already cleared: \(error)")
        }
    }

    /// Claims the single in-flight authentication slot. Logs and returns `false` when another attempt holds it.
    private func beginAuthenticating(_ kind: AuthProvider.Kind) -> Bool {
        guard authenticatingProvider == nil else {
            logger.debug(.auth, "Ignored authentication via \(kind.rawValue): another attempt is in progress")
            return false
        }
        authenticatingProvider = kind
        return true
    }

    private func performSignIn(with provider: AuthProvider) async -> Bool {
        logger.info(.auth, "Sign-in started via \(provider.kind.rawValue)")
        do {
            let session = try await authService.signIn(with: provider)
            logger.info(.auth, "Sign-in succeeded via \(provider.kind.rawValue)")
            state = .signedIn(session.user)
            return true
        } catch is CancellationError {
            // The user backed out (dismissed the sheet); not an error to show.
            logger.info(.auth, "Sign-in cancelled via \(provider.kind.rawValue)")
            return false
        } catch {
            logger.error(.auth, "Sign-in failed via \(provider.kind.rawValue): \(error)")
            errorCenter.report(mapSignInError(error, provider: provider))
            return false
        }
    }

    private func mapSignInError(_ error: any Error, provider: AuthProvider) -> AppError {
        let wrapped = AppError.wrapping(error)
        return wrapped == .unknown ? .authFailed(provider: provider.kind) : wrapped
    }
}
