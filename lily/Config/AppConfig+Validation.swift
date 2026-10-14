import Foundation

nonisolated extension AppConfig.Auth {
    /// The longest local part (before the `@`) an email may have, in UTF-16 units, as Laurel's `@Email` (Hibernate
    /// Validator) measures it; a longer one is a 400 no retry gets past. The whole address is capped at the contact
    /// form by `AppConfig.Feedback.replyEmailMaxLength`.
    static let emailLocalPartMaxLength = 64
}
