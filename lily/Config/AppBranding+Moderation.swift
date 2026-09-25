import Foundation

nonisolated extension AppBranding {
    /// Copy of reporting, blocking, the terms sheet and the operator queue.
    enum Moderation {
        static let report = "Report"
        static let reportMessage = "Report message"
        static let reportUser = "Report user"
        static let block = "Block"
        static let unblock = "Unblock"
        static let blockedUsers = "Blocked users"
        static let blockedEmptyTitle = "Nobody blocked"
        static let blockedEmptyMessage = "People you block disappear from your chats."
        static let reasonTitle = "Why are you reporting this?"
        static let reasonSpam = "Spam"
        static let reasonHarassment = "Harassment or hate"
        static let reasonInappropriate = "Inappropriate content"
        static let reasonOther = "Something else"
        static let commentPlaceholder = "Anything else we should know? (optional)"
        static let submit = "Send report"
        static let thanks = "Thanks, we'll look into it"
        static let contactFormat = "Questions? Write to %@"
        static let termsTitle = "Before you join in"
        static let termsMessage = "Be kind. There is zero tolerance for objectionable content or abusive behaviour: "
            + "offending messages are removed and the accounts behind them are suspended."
        static let termsLink = "Terms of use"
        static let privacyLink = "Privacy policy"
        static let supportLink = "Support"
        static let accept = "I agree"
        static let queueTitle = "Reports"
        static let queueEmptyTitle = "All clear"
        static let queueEmptyMessage = "Open reports show up here."
        static let resolve = "Resolve"
        static let suspendAccount = "Suspend account"
        static let suspendConfirmationFormat = "Suspend this account? %@ is signed out everywhere and cannot sign in again."

        static func contact(email: String) -> String {
            String(format: contactFormat, email)
        }
    }
}
