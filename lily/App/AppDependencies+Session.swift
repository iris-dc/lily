import Foundation

/// The session choice the app restores, settled from the launch arguments before the session controller is built, and
/// the session's end when the pool refuses to refresh the token.
extension AppDependencies {
    /// `-reset-session`, judged once and logged once; `makeDefault` hands the answer to every store factory.
    static func startsFresh(arguments: [String], logger: any Logging) -> Bool {
        guard arguments.contains(AppConfig.LaunchArguments.resetSession) else { return false }
        logger.info(.auth, "Launch argument requested a fresh start: stored session, choices, filter and snapshots cleared")
        return true
    }

    /// The persisted session choice, cleared on a fresh start (`-reset-session`, decided and logged once by
    /// `makeDefault`) and set to the guest by `-start-as-guest`.
    static func makeSessionStore(arguments: [String],
                                 startsFresh: Bool,
                                 defaults: UserDefaults,
                                 logger: any Logging) -> UserDefaultsSessionStore {
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        if startsFresh { store.clear() }
        if arguments.contains(AppConfig.LaunchArguments.startAsGuest) {
            logger.info(.auth, "Launch argument requested guest mode")
            store.save(.guest)
        }
        return store
    }

    /// A refresh token the pool refuses mid-session ends the session through the controller. Weak, since the controller
    /// holds the service that fires this; a `Task`, since the hook fires inside a request's build and must not hold it.
    func wireSessionExpiry(_ reporter: (any SessionExpiryReporter)?) {
        let controller = sessionController
        reporter?.onSessionExpired = { [weak controller] in
            Task { await controller?.endExpiredSession() }
        }
    }
}
