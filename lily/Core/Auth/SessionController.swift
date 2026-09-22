import Foundation
import Observation

/// Owns the session state machine. Views read `state`; all mutations go through the methods below.
@Observable
final class SessionController {
    private(set) var state: SessionState = .loading
    /// Provider currently mid sign-in, so buttons can show a spinner without a second source of truth.
    private(set) var authenticatingProvider: AuthProvider.Kind?
    /// Display-name sync started by the last sign-in. Sign-in never waits for it; sign-out cancels it.
    private(set) var profileSync: Task<Void, Never>?
    private var isSigningOut = false

    private let authService: any AuthService
    private let sessionStore: any SessionStore
    private let profileRepository: any ProfileRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(authService: any AuthService,
         sessionStore: any SessionStore,
         profileRepository: any ProfileRepository,
         errorCenter: ErrorCenter,
         logger: any Logging) {
        self.authService = authService
        self.sessionStore = sessionStore
        self.profileRepository = profileRepository
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

    /// Provider sign-in. Returns `true` on success; failures are reported through the shared error popup.
    @discardableResult
    func signIn(with provider: AuthProvider) async -> Bool {
        await authenticating(provider.kind) { await performSignIn(with: provider) } == .signedIn
    }

    /// Email sign-in; `.confirmationRequired` (the account never entered its code) shows no popup, the form takes over.
    func signIn(withEmail credentials: EmailCredentials) async -> EmailAuthResult {
        await authenticating(.email) { await performSignIn(with: .email(credentials)) }
    }

    /// Holds the authentication slot for the whole sign-up, so a provider tap cannot interleave with it.
    @discardableResult
    func signUp(email: String, password: String) async -> EmailAuthResult {
        await authenticating(.email) {
            do {
                switch try await authService.signUp(email: email, password: password) {
                case .signedUp:
                    logger.info(.auth, "Sign-up succeeded")
                    return await performSignIn(with: .email(EmailCredentials(email: email, password: password)))
                case .confirmationRequired:
                    logger.info(.auth, "Sign-up needs email confirmation")
                    return .confirmationRequired
                }
            } catch {
                return report(error, during: "Sign-up")
            }
        }
    }

    /// Confirms the emailed code, then signs in with the password the form kept.
    @discardableResult
    func confirmSignUp(email: String, code: String, password: String) async -> Bool {
        await authenticating(.email) {
            do {
                try await authService.confirmSignUp(email: email, code: code)
                logger.info(.auth, "Email confirmed")
            } catch {
                return report(error, during: "Confirmation")
            }
            return await performSignIn(with: .email(EmailCredentials(email: email, password: password)))
        } == .signedIn
    }

    @discardableResult
    func resendConfirmationCode(email: String) async -> Bool {
        do {
            try await authService.resendConfirmationCode(email: email)
            logger.info(.auth, "Confirmation code resent")
            return true
        } catch {
            report(error, during: "Resend")
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
        profileSync?.cancel()
        let userID = state.user?.id
        sessionStore.clear()
        state = .signedOut
        logger.info(.auth, userID.map { "Signed out user \($0)" } ?? "Signed out")
        do {
            try await authService.signOut()
        } catch {
            logger.warning(.auth, "Remote sign-out failed, local session already cleared: \(error)")
        }
    }

    /// Runs `attempt` holding the single in-flight authentication slot; `.failed` without a popup when another holds it.
    private func authenticating(_ kind: AuthProvider.Kind, _ attempt: () async -> EmailAuthResult) async -> EmailAuthResult {
        guard authenticatingProvider == nil else {
            logger.debug(.auth, "Ignored authentication via \(kind.rawValue): another attempt is in progress")
            return .failed
        }
        authenticatingProvider = kind
        defer { authenticatingProvider = nil }
        return await attempt()
    }

    private func performSignIn(with provider: AuthProvider) async -> EmailAuthResult {
        let via = "via \(provider.kind.rawValue)"
        logger.info(.auth, "Sign-in started \(via)")
        do {
            let session = try await authService.signIn(with: provider)
            logger.info(.auth, "Sign-in succeeded \(via) for user \(session.user.id)")
            state = .signedIn(session.user)
            syncProfile(for: session.user)
            return .signedIn
        } catch AppError.emailNotConfirmed {
            logger.info(.auth, "Sign-in needs email confirmation")
            return .confirmationRequired
        } catch {
            return report(error, during: "Sign-in \(via)", fallback: .authFailed(provider: provider.kind))
        }
    }

    /// Logs a failed step and shows it, except a cancellation (the user backed out): that is logged quietly. Always `.failed`.
    @discardableResult
    private func report(_ error: any Error, during step: String, fallback: AppError = .unknown) -> EmailAuthResult {
        if error is CancellationError {
            logger.info(.auth, "\(step) cancelled")
            return .failed
        }
        let wrapped = AppError.wrapping(error)
        if case .providerUnavailable = wrapped {
            logger.warning(.auth, "\(step) refused: \(error)")
        } else {
            logger.error(.auth, "\(step) failed: \(error)")
        }
        errorCenter.report(wrapped == .unknown ? fallback : wrapped)
        return .failed
    }

    /// The backend copies the host's name onto events, so it must know it before the user hosts one. Fire and forget:
    /// the user did sign in, so a failure here is logged and never shown. A sign-out cancels it on purpose, which
    /// is not a failure and stays at debug.
    private func syncProfile(for user: AuthUser) {
        profileSync?.cancel()
        profileSync = Task { [profileRepository, logger] in
            do {
                try await profileRepository.syncDisplayName(user.displayName)
                logger.info(.auth, "Profile synced for user \(user.id)")
            } catch {
                if AppError.isCancellation(error) {
                    logger.debug(.auth, "Profile sync cancelled for user \(user.id)")
                } else {
                    logger.warning(.auth, "Profile sync failed for user \(user.id): \(error)")
                }
            }
        }
    }
}
