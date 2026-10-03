import Foundation

nonisolated extension AppConfig.LaunchArguments {
    /// Takes the next argument as a language code (`-app-language ru`) and shows the app in it for this run only, so
    /// screenshots of every language need no tap on Profile; an unknown code is ignored with a warning.
    static let appLanguage = "-app-language"

    /// The language a launch asked for, `nil` without the flag or with a code the catalog does not carry.
    static func appLanguage(from arguments: [String]) -> AppLanguage? {
        value(following: appLanguage, in: arguments).flatMap(AppLanguage.init(localization:))
    }
}
