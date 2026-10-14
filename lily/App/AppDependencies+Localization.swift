import Foundation

/// The language the app shows, settled from the stored choice and the launch arguments before anything else is built.
extension AppDependencies {
    /// The stored language choice, forgotten on a fresh start (`-reset-session`, decided and logged once by
    /// `makeDefault`) and overridden for this run alone by `-app-language <code>`. `apply` moves the process-wide
    /// `AppLocale`; the tests pass a spy, so none of them changes the language every other suite reads its copy in.
    static func makeLanguageStore(arguments: [String],
                                  startsFresh: Bool,
                                  defaults: UserDefaults,
                                  logger: any Logging,
                                  apply: @escaping (AppLocale.Context) -> Void = AppLocale.set) -> LanguageStore {
        let store = UserDefaultsChoiceStore<LanguagePreference>(defaults: defaults, logger: logger)
        if startsFresh { store.clear() }
        let launchChoice = AppConfig.LaunchArguments.appLanguage(from: arguments)
        logLanguageArgument(launchChoice, in: arguments, logger: logger)
        return LanguageStore(store: store, launchChoice: launchChoice, apply: apply, logger: logger)
    }

    /// What `-app-language` asked for: a shipped language, a code the catalog does not carry, or no value at all (the
    /// flag last or followed by another flag). A language code is neither a secret nor PII, so the line names it.
    private static func logLanguageArgument(_ launchChoice: AppLanguage?, in arguments: [String], logger: any Logging) {
        let flag = AppConfig.LaunchArguments.appLanguage
        if let launchChoice {
            logger.info(.localization, "Launch argument set the language to \(launchChoice.code)")
        } else if let code = AppConfig.LaunchArguments.value(following: flag, in: arguments) {
            logger.warning(.localization, "Launch argument asked for a language the app does not ship (\(code)); ignored")
        } else if arguments.contains(flag) {
            logger.warning(.localization, "Launch argument \(flag) has no value; ignored")
        }
    }
}
