import Foundation

nonisolated extension AppBranding {
    /// The tombstone of a deleted account, wherever their messages, games and results remain (`Tombstone`).
    enum DeletedUser {
        static var name: String { localized("Deleted user") }
    }

    /// Copy of the delete-account flow: the Settings row and the sheet it presents — the summary (one plural line per
    /// non-zero count, composed by `DeleteAccountViewModel.rows(for:)`, with the always-true messages sentence), the
    /// destructive confirmation, the locked wait and the one-time acknowledgment.
    enum DeleteAccount {
        static var title: String { localized("Delete account") }
        static var approximate: String { localized("These counts are approximate.") }
        static var messagesSentence: String { localized("Your messages will show as Deleted user.") }
        static var irreversible: String { localized("Deleting your account cannot be undone.") }
        static var dialogTitle: String { localized("Delete your account?") }
        static var confirmAction: String { localized("Delete my account") }
        static var deleting: String { localized("Deleting your account…") }
        static var deletedTitle: String { localized("Your account was deleted") }
        static var deletedMessage: String { localized("Your sign-in and profile were removed.") }
        static var acknowledgeAction: String { localized("Done") }

        static func groupsTransferring(_ count: Int) -> String { localized("\(count) groups will pass to another member") }
        static func groupsDeleted(_ count: Int) -> String { localized("\(count) groups will be deleted") }
        static func eventsCancelled(_ count: Int) -> String {
            localized("\(count) upcoming games you host will be cancelled")
        }
        static func entriesWithdrawn(_ count: Int) -> String { localized("\(count) tournament entries will be withdrawn") }
        static func tournamentsCancelled(_ count: Int) -> String {
            localized("\(count) tournaments you organize will be cancelled")
        }
    }

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

    /// Copy of the bio: the "About you" card on Profile and the sheet that edits it.
    enum About {
        static var title: String { localized("About you") }
        /// The card's line while nothing is written: a nudge to write something.
        static var emptySubtitle: String { localized("Tell other players about yourself") }
        static var placeholder: String { localized("A few words about you") }
        static var footer: String { localized("Shown on your profile to other players.") }
        static var save: String { Events.Edit.save }

        /// Under the field once the text is over the backend's cap.
        static func tooLong(limit: Int) -> String {
            localized("Keep it under \(limit) characters")
        }
    }
}
