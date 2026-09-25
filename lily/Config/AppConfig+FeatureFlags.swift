import Foundation

nonisolated extension AppConfig {
    /// Switches for features that ship in debug builds before they are ready for release. Each one is flipped in
    /// release by the milestone that finishes the feature.
    enum FeatureFlags {
        #if DEBUG
        /// The Groups tab and group-hosted events.
        static let groups = true
        /// Chat rows and screens. With `groups` on and `chat` off, a group row opens the group instead of its chat.
        static let chat = true
        #else
        static let groups = false
        static let chat = false
        #endif
    }
}
