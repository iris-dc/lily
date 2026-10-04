import Foundation

nonisolated extension AppBranding {
    /// Copy of reporting, blocking, the terms sheet and the operator queue.
    enum Moderation {
        static var report: String { localized("Report") }
        static var reportMessage: String { localized("Report message") }
        static var reportUser: String { localized("Report user") }
        static var block: String { localized("Block") }
        static var unblock: String { localized("Unblock") }
        static var blockedUsers: String { localized("Blocked users") }
        static var blockedEmptyTitle: String { localized("Nobody blocked") }
        static var blockedEmptyMessage: String { localized("People you block disappear from your chats.") }
        static var reasonTitle: String { localized("Why are you reporting this?") }
        static var reasonSpam: String { localized("Spam") }
        static var reasonHarassment: String { localized("Harassment or hate") }
        static var reasonInappropriate: String { localized("Inappropriate content") }
        static var reasonOther: String { localized("Something else") }
        static var commentPlaceholder: String { localized("Anything else we should know? (optional)") }
        /// The bar button: one word, so the inline title beside it is not squeezed to "Report tourna…" (seen 2026-10-04).
        static var send: String { Chat.send }
        static var thanks: String { localized("Thanks, we'll look into it") }
        /// Under `thanks` once a report went out.
        static var thanksMessage: String { localized("We review every report and act where the terms were broken.") }
        static var done: String { Groups.Invite.done }
        static var termsTitle: String { localized("Before you join in") }
        static var termsMessage: String {
            localized("""
                Be kind. There is zero tolerance for objectionable content or abusive behaviour: \
                offending messages are removed and the accounts behind them are suspended.
                """)
        }
        static var termsLink: String { localized("Terms of use") }
        static var privacyLink: String { localized("Privacy policy") }
        static var supportLink: String { localized("Support") }
        static var accept: String { localized("I agree") }
        static var queueTitle: String { localized("Reports") }
        static var queueEmptyTitle: String { localized("All clear") }
        static var queueEmptyMessage: String { localized("Open reports show up here.") }
        static var resolve: String { localized("Resolve") }
        static var suspendAccount: String { localized("Suspend account") }

        static func contact(email: String) -> String {
            localized("Questions? Write to \(email)")
        }
    }
}
