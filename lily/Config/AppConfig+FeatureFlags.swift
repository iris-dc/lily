import Foundation

nonisolated extension AppConfig {
    /// Named switches for the features that once shipped dark; all on in every configuration now that the realtime
    /// transport is real, and kept as flags so a feature can still be pulled from a build in one line.
    enum FeatureFlags {
        /// Groups (on Home and Explore) and group-hosted events.
        static let groups = true
        /// Chat rows and screens. With `groups` on and `chat` off, a group row opens the group instead of its chat.
        static let chat = true
    }
}
