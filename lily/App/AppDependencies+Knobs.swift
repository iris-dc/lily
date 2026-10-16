import Foundation

/// The debug launch arguments that only the UI tests set, read into the composition root with a line in the log each.
extension AppDependencies {
    /// The shared error funnel; `-hold-popups` keeps every popup up until it is dismissed, for UI tests on a runner too
    /// slow to catch a popup that fades after a few seconds.
    static func makeErrorCenter(arguments: [String], logger: any Logging) -> ErrorCenter {
        guard arguments.contains(AppConfig.LaunchArguments.holdPopups) else { return ErrorCenter(logger: logger) }
        logger.info(.ui, "Launch argument holds error popups until dismissed")
        return ErrorCenter(logger: logger, autoDismissDelay: nil)
    }

    /// `-freeze-aurora`: the aurora stays on its first frame, which spares the simulator's compositor the 30 fps redraw
    /// that starves a runner rendering in software.
    static func freezesAurora(arguments: [String], logger: any Logging) -> Bool {
        guard arguments.contains(AppConfig.LaunchArguments.freezeAurora) else { return false }
        logger.info(.ui, "Launch argument freezes the aurora on its first frame")
        return true
    }
}
