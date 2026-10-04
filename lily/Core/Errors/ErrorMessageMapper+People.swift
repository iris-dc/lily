import Foundation

/// Copy for profiles and direct conversations; `message(for:)` routes those cases here, and the tournament cases fall
/// through to `tournamentMessage(for:)` so the main switch stays under the complexity limit.
nonisolated extension ErrorMessageMapper {
    static func peopleMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .profileUnavailable:
            ErrorMessage(title: localized("Couldn't load this profile"), body: localized("Please try again in a moment."))
        case .conversationFailed:
            ErrorMessage(title: localized("Couldn't start the conversation"), body: localized("Please try again in a moment."))
        case .conversationLimit:
            ErrorMessage(title: localized("You have too many conversations"),
                         body: localized("You can have at most \(AppConfig.People.maxConversations) conversations."))
        default:
            tournamentMessage(for: error)
        }
    }
}
