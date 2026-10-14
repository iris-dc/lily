import Foundation

nonisolated extension AppBranding {
    /// Copy of reporting, blocking and the terms sheet.
    enum Moderation {
        static var report: String { localized("Report") }
        static var reportMessage: String { localized("Report message") }
        static var block: String { localized("Block") }
        /// The confirmation before a block: "Block Marta?" over the line that says what a block does.
        static func blockConfirmationTitle(name: String) -> String { localized("Block \(name)?") }
        static var blockConfirmationMessage: String { localized("People you block disappear from your chats.") }
        static var reasonTitle: String { localized("Why are you reporting this?") }
        static var reasonSpam: String { localized("Spam") }
        static var reasonHarassment: String { localized("Harassment or hate") }
        static var reasonInappropriate: String { localized("Inappropriate content") }
        static var reasonOther: String { localized("Something else") }
        static var commentPlaceholder: String { localized("Anything else we should know? (optional)") }
        /// The bar button: one word, so the inline title beside it is not squeezed to "Report tourna…".
        static var send: String { Chat.send }
        static var thanks: String { localized("Thanks, we'll look into it") }
        /// Under `thanks` once a report went out.
        static var thanksMessage: String { localized("We review every report and act where the terms were broken.") }
        static var done: String { AppBranding.done }
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

        static func contact(email: String) -> String {
            localized("Questions? Write to \(email)")
        }
    }
}
