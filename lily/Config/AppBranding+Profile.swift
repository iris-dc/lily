import Foundation

nonisolated extension AppBranding {
    /// Copy of the display name: the card on Profile and the sheet that edits it.
    enum DisplayName {
        static var title: String { localized("Display name") }
        static var subtitle: String { localized("What other players see") }
        /// The card's line while the name is still the backend's default: a nudge to pick one.
        static var defaultSubtitle: String { localized("Choose a name other players will see") }
        static var placeholder: String { localized("Your name") }
        static var footer: String { localized("Shown on the events you host, in groups and in chats.") }
        static var save: String { Events.Edit.save }

        /// Under the field once the name is over the backend's cap.
        static func tooLong(limit: Int) -> String {
            localized("Keep your name under \(limit) characters")
        }
    }
}
