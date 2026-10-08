import Foundation

/// What a message to us is about; the raw values are the wire names of Laurel's `FeedbackKind`.
nonisolated enum FeedbackKind: String, CaseIterable, Codable, Sendable {
    case contact, feedback, bug

    var displayName: String {
        switch self {
        case .contact: AppBranding.Feedback.kindContact
        case .feedback: AppBranding.Feedback.kindFeedback
        case .bug: AppBranding.Feedback.kindBug
        }
    }

    /// The message field's placeholder, a question that fits the kind.
    var messagePlaceholder: String {
        switch self {
        case .contact: AppBranding.Feedback.contactPlaceholder
        case .feedback: AppBranding.Feedback.feedbackPlaceholder
        case .bug: AppBranding.Feedback.bugPlaceholder
        }
    }
}

/// Body of `POST /api/feedback`. Optionals are omitted, never sent as `null`.
nonisolated struct FeedbackPayload: Encodable, Equatable, Sendable {
    let kind: FeedbackKind
    let message: String
    let replyEmail: String?
    let appVersion: String?
    let osVersion: String?
    let device: String?
    let locale: String?
}

/// Answer of `POST /api/feedback`: the stored item's handle.
nonisolated struct FeedbackReceipt: Hashable, Codable, Sendable {
    let id: String
    let createdAt: Date
}
