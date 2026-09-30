import Foundation

/// Copy for profiles and direct conversations; `message(for:)` routes exactly those cases here.
nonisolated extension ErrorMessageMapper {
    static func peopleMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .profileUnavailable:
            ErrorMessage(title: "Couldn't load this profile", body: "Please try again in a moment.")
        case .conversationFailed:
            ErrorMessage(title: "Couldn't start the conversation", body: "Please try again in a moment.")
        case .conversationLimit:
            ErrorMessage(title: "You have too many conversations",
                         body: "You can have at most \(AppConfig.People.maxConversations) conversations.")
        default:
            unknownMessage
        }
    }
}
