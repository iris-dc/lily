import Foundation

nonisolated extension AppBranding {
    /// Copy every draft sheet shares.
    enum Forms {
        static var close: String { localized("Close") }
        static var back: String { localized("Back") }
        static var cancel: String { localized("Cancel") }

        /// The hints the event, group and tournament forms and the contact form share, each naming the limit the
        /// field was judged against.
        static func nameTooLong(limit: Int) -> String { localized("Keep the name under \(limit) characters") }
        static func descriptionTooLong(limit: Int) -> String { localized("Keep the description under \(limit) characters") }
        static var placeNameMissing: String { localized("Name the place") }
        static func placeNameTooLong(limit: Int) -> String { localized("Keep the place name under \(limit) characters") }
        static func startTooSoon(minutes: Int) -> String { localized("Pick a start at least \(minutes) minutes from now") }
        static func tooLong(limit: Int) -> String { localized("Keep it under \(limit) characters") }
    }
}
