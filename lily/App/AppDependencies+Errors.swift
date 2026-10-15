import Foundation

extension AppDependencies {
    /// The shared error funnel; `-hold-popups` keeps every popup up until it is dismissed, for UI tests on a runner too
    /// slow to catch a popup that fades after a few seconds.
    static func makeErrorCenter(arguments: [String], logger: any Logging) -> ErrorCenter {
        guard arguments.contains(AppConfig.LaunchArguments.holdPopups) else { return ErrorCenter(logger: logger) }
        logger.info(.ui, "Launch argument holds error popups until dismissed")
        return ErrorCenter(logger: logger, autoDismissDelay: nil)
    }
}
