import Foundation

nonisolated extension AppBranding {
    /// Copy of the contact form: the row on Profile, the sheet, its hints and the thanks.
    enum Feedback {
        static var rowTitle: String { localized("Contact & feedback") }
        static var rowSubtitle: String { localized("Questions, ideas and bug reports") }
        static var title: String { localized("Contact us") }
        static var kindTitle: String { localized("What is it about?") }
        static var kindContact: String { localized("Question") }
        static var kindFeedback: String { localized("Feedback") }
        static var kindBug: String { localized("Bug") }
        static var messageTitle: String { localized("Your message") }
        static var contactPlaceholder: String { localized("How can we help?") }
        static var feedbackPlaceholder: String { localized("What should we change or keep?") }
        static var bugPlaceholder: String { localized("What happened, and what did you expect?") }
        static var replyEmailTitle: String { localized("Reply-to email") }
        static var replyEmailFooter: String { localized("Optional. We answer here when you want a reply.") }
        static var invalidEmail: String { localized("That email doesn't look right") }
        /// The bar button: one word, so the inline title beside it is never squeezed.
        static var send: String { Chat.send }
        static var thanks: String { localized("Thanks for writing") }
        static var thanksMessage: String {
            localized("We read every message and reply by email when you ask for an answer.")
        }
        static var done: String { Groups.Invite.done }

        /// Under the email field: what is attached to every message, so the caller sees it before sending.
        static func attachedDetails(_ summary: String) -> String {
            localized("To help us reproduce issues we attach your app version, iOS version and device model: \(summary)")
        }

        /// Under the message or the email once it is over the backend's cap.
        static func tooLong(limit: Int) -> String {
            localized("Keep it under \(limit) characters")
        }
    }
}
