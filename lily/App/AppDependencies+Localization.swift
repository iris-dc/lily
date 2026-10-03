import Foundation

/// The language the app shows, settled from the stored choice and the launch arguments before anything else is built.
extension AppDependencies {
    /// The stored language choice, forgotten by `-reset-session` (a fresh start for UI tests and screenshots) and
    /// overridden for this run alone by `-app-language <code>`. `apply` moves the process-wide `AppLocale`; the tests
    /// pass a spy, so none of them changes the language every other suite reads its copy in.
    static func makeLanguageStore(arguments: [String],
                                  defaults: UserDefaults,
                                  logger: any Logging,
                                  apply: @escaping (AppLanguage?) -> Void = AppLocale.set) -> LanguageStore {
        let store = UserDefaultsLanguagePreferenceStore(defaults: defaults)
        if arguments.contains(AppConfig.LaunchArguments.resetSession) { store.clear() }
        let launchChoice = AppConfig.LaunchArguments.appLanguage(from: arguments)
        if let launchChoice {
            logger.info(.localization, "Launch argument set the language to \(launchChoice.code)")
        } else if arguments.contains(AppConfig.LaunchArguments.appLanguage) {
            logger.warning(.localization, "Launch argument asked for a language the app does not ship; ignored")
        }
        return LanguageStore(store: store, launchChoice: launchChoice, apply: apply, logger: logger)
    }
}
