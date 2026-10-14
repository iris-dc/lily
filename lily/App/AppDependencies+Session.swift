import Foundation

/// The session choice the app restores, settled from the launch arguments before the session controller is built.
extension AppDependencies {
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
}
