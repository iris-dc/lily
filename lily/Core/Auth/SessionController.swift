import Foundation
import Observation

/// Owns the session state machine. Views read `state`; all mutations go through the methods below. The state starts
/// from the cached choice (the guest, or the user last seen signed in), so the first frame is the right screen with no
/// network answer awaited; `restore()` then verifies the cache with the pool and settles any disagreement. The email
/// sign-up and confirmation steps are in `SessionController+EmailConfirmation.swift`.
@Observable
final class SessionController {
    private(set) var state: SessionState
    /// Provider currently mid sign-in, so buttons can show a spinner without a second source of truth.
    private(set) var authenticatingProvider: AuthProvider.Kind?
    /// Display-name sync started by the last sign-in. Sign-in never waits for it; sign-out cancels it.
    private(set) var profileSync: Task<Void, Never>?
    private var isSigningOut = false
    /// The one check of the cached session against the pool; a second `restore()` joins it instead of asking again.
    private var restoreCheck: Task<Void, Never>?
    /// Held weakly: an observer lives as long as its owner, never because it registered here.
    private var observers: [WeakSessionObserver] = []

    let authService: any AuthService
    private let sessionStore: any SessionStore
    private let profileRepository: any ProfileRepository
    private let errorCenter: ErrorCenter
    let logger: any Logging

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
        state = Self.state(cached: sessionStore.load())
    }

    /// Verifies the cached session with the pool, once per process (a later call joins the check), and settles the
    /// answer over the state the first frame showed: a pool without a session ends a cached one like a sign-out, a pool
    /// session the cache missed signs in, and a check that could not be made keeps the cache, the backend's 401 deciding.
    func restore() async {
        if restoreCheck == nil {
            restoreCheck = Task { await verifyCachedSession() }
        }
        await restoreCheck?.value
    }

    /// The screen the first frame shows: a sign-out marker reads as signed out, since the pool is told on `restore()`.
    private static func state(cached: StoredSession?) -> SessionState {
        switch cached {
        case .signedIn(let session): .signedIn(session.user)
        case .guest: .guest
        case .signingOut, nil: .signedOut
        }
    }

    private func verifyCachedSession() async {
        let cached = state
        let verified: AuthSession?
        do {
            verified = try await authService.restoreSession()
        } catch {
            logger.info(.auth, "Could not verify the cached session, keeping it: \(error)")
            return
        }
        guard state == cached else {
            logger.debug(.auth, "Session changed during the restore check; the check's answer is dropped")
            // The service writes the store while it checks; a guest choice made meanwhile must be what the next launch reads.
            if state == .guest { sessionStore.save(.guest) }
            return
        }
        switch (verified, cached) {
        case (let session?, .signedIn(let user)) where session.user == user:
            logger.debug(.auth, "Session verified for user \(user.id)")
        case (let session?, _):
            logger.info(.auth, "Session restored for user \(session.user.id)")
            state = .signedIn(session.user)
        case (nil, .signedIn(let user)):
            // The service signed the pool out where that was due; only the session on the device is left to end.
            logger.warning(.auth, "Cached session dropped: the pool has no session for user \(user.id)")
            await holdingSignOutSlot { await endLocalSession() }
        case (nil, _):
            logger.info(.auth, cached == .guest ? "Restored guest mode" : "No stored session")
        }
    }

    /// Provider sign-in. Returns `true` on success; failures are reported through the shared error popup.
    @discardableResult
    func signIn(with provider: AuthProvider) async -> Bool {
        await authenticating(provider.kind, busy: .failed) { await performSignIn(with: provider) } == .signedIn
    }

    /// Email sign-in; `.confirmationRequired` (the account never entered its code) shows no popup, the form takes over.
    func signIn(withEmail credentials: EmailCredentials) async -> EmailAuthResult {
        await authenticating(.email, busy: .failed) { await performSignIn(with: .email(credentials)) }
    }

    func continueAsGuest() {
        logger.info(.auth, "Continuing as guest")
        sessionStore.save(.guest)
        state = .guest
    }

    /// Registers per-user state to be cleared when the session ends. `Core/Auth` never has to know what it is.
    func addObserver(_ observer: any SessionObserver) {
        observers.append(WeakSessionObserver(observer))
    }

    /// Ends the session on the device, then at the pool; the local part comes first, so a late duplicate cannot undo a
    /// choice made meanwhile.
    func signOut() async {
        await holdingSignOutSlot {
            guard await endLocalSession() else { return }
            do {
                try await authService.signOut()
            } catch {
                logger.warning(.auth, "Remote sign-out failed, local session already cleared: \(error)")
            }
        }
    }

    /// Runs `body` as the one sign-out in flight; a second caller is turned away and does nothing.
    private func holdingSignOutSlot(_ body: () async -> Void) async {
        guard !isSigningOut else {
            logger.debug(.auth, "Ignored sign-out: another sign-out is in progress")
            return
        }
        isSigningOut = true
        defer { isSigningOut = false }
        await body()
    }

    /// Ends the session on the device: observers get a last word while the user is still signed in (a device to
    /// unregister), then the store and the state clear before anyone is told it ended. `false` when the session changed
    /// hands during that last word (a sign-in landed meanwhile), which stands.
    @discardableResult
    private func endLocalSession() async -> Bool {
        let ending = state
        profileSync?.cancel()
        await notifySessionWillEnd()
        guard state == ending else {
            logger.debug(.auth, "Session changed while it was ending; the sign-out stands down")
            return false
        }
        sessionStore.clear()
        state = .signedOut
        logger.info(.auth, ending.user.map { "Signed out user \($0.id)" } ?? "Signed out")
        notifySessionEnded()
        return true
    }

    private func notifySessionWillEnd() async {
        for observer in observers {
            await observer.observer?.sessionWillEnd()
        }
    }

    /// Observers whose owner is gone are dropped on the way, so the list never grows past the live ones.
    private func notifySessionEnded() {
        observers.removeAll { $0.observer == nil }
        observers.forEach { $0.observer?.sessionDidEnd() }
    }

    /// Runs `attempt` holding the single in-flight authentication slot; `busy` without a popup when another holds it.
    func authenticating<Outcome>(_ kind: AuthProvider.Kind,
                                 busy: Outcome,
                                 _ attempt: () async -> Outcome) async -> Outcome {
        guard authenticatingProvider == nil else {
            logger.debug(.auth, "Ignored authentication via \(kind.rawValue): another attempt is in progress")
            return busy
        }
        authenticatingProvider = kind
        defer { authenticatingProvider = nil }
        return await attempt()
    }

    func performSignIn(with provider: AuthProvider) async -> EmailAuthResult {
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
    func report(_ error: any Error, during step: String, fallback: AppError = .unknown) -> EmailAuthResult {
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

private struct WeakSessionObserver {
    weak var observer: (any SessionObserver)?

    init(_ observer: any SessionObserver) {
        self.observer = observer
    }
}
