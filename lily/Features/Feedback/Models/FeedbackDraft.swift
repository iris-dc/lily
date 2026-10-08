import Foundation

/// The contact form's state and its validation, judged against `AppConfig.Feedback` so a passing draft is never
/// refused for its shape. The reply email starts as the account's and may be cleared.
nonisolated struct FeedbackDraft: Equatable, Sendable {
    var kind: FeedbackKind
    var message: String
    var replyEmail: String

    init(kind: FeedbackKind = .feedback, message: String = "", replyEmail: String? = nil) {
        self.kind = kind
        self.message = message
        self.replyEmail = replyEmail ?? ""
    }

    var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEmail: String { replyEmail.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// In form order; empty when the draft may go out.
    var issues: [FeedbackIssue] {
        var issues: [FeedbackIssue] = []
        if trimmedMessage.isEmpty {
            issues.append(.messageMissing)
        } else if trimmedMessage.wireLength > AppConfig.Feedback.messageMaxLength {
            issues.append(.messageTooLong)
        }
        if !trimmedEmail.isEmpty {
            if !CredentialsValidator.isValidEmail(trimmedEmail) {
                issues.append(.emailInvalid)
            } else if trimmedEmail.wireLength > AppConfig.Feedback.replyEmailMaxLength {
                issues.append(.emailTooLong)
            }
        }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// The line worth showing under one field, if any; a missing message only keeps Send disabled.
    func hint(for field: FeedbackField) -> String? {
        issues.first { $0.field == field }?.hint
    }

    /// The one place a draft becomes the request body: trimmed words, a blank email left out, the environment's
    /// details cut to what the backend accepts.
    func payload(in environment: FeedbackEnvironment) -> FeedbackPayload {
        let cap = AppConfig.Feedback.detailMaxLength
        return FeedbackPayload(kind: kind,
                               message: trimmedMessage,
                               replyEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
                               appVersion: environment.appVersion.prefix(wireLength: cap),
                               osVersion: environment.osVersion.prefix(wireLength: cap),
                               device: environment.device.prefix(wireLength: cap),
                               locale: environment.locale)
    }
}

nonisolated enum FeedbackField: Equatable, Sendable {
    case message, replyEmail
}

nonisolated enum FeedbackIssue: Equatable, Sendable {
    case messageMissing, messageTooLong, emailInvalid, emailTooLong

    var field: FeedbackField {
        switch self {
        case .messageMissing, .messageTooLong: .message
        case .emailInvalid, .emailTooLong: .replyEmail
        }
    }

    /// The copy under the field; `nil` for a missing message, which the empty field explains by itself.
    var hint: String? {
        switch self {
        case .messageMissing: nil
        case .messageTooLong: AppBranding.Feedback.tooLong(limit: AppConfig.Feedback.messageMaxLength)
        case .emailInvalid: AppBranding.Feedback.invalidEmail
        case .emailTooLong: AppBranding.Feedback.tooLong(limit: AppConfig.Feedback.replyEmailMaxLength)
        }
    }
}
