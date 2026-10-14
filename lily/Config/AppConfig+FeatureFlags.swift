import Foundation

nonisolated extension AppConfig {
    /// Switches for features that ship in debug builds before they are ready for release. Off in release while
    /// `GroupRepositories.remote` wires `NoRealtimeTransport` (a release room would never be live) and the terms gate
    /// (`TermsSheet` answering `TERMS_REQUIRED`) is untested against Laurel end to end; `tournaments` is in
    /// `AppConfig+Tournaments.swift` under the same rule.
    enum FeatureFlags {
        #if DEBUG
        /// Groups (on Home and Explore) and group-hosted events.
        static let groups = true
        /// Chat rows and screens. With `groups` on and `chat` off, a group row opens the group instead of its chat.
        static let chat = true
        #else
        static let groups = false
        static let chat = false
        #endif
    }
}
