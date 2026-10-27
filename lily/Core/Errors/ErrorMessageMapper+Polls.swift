import Foundation

/// Copy for polls and pins, the chat cases `chatMessage(for:)` has no copy of its own for.
nonisolated extension ErrorMessageMapper {
    static func pollAndPinMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .pollsNotAllowed:
            ErrorMessage(title: localized("Polls aren't available here"),
                         body: localized("Polls can be created in group chats."))
        case .notAPoll:
            ErrorMessage(title: localized("That's not a poll"), body: localized("This message can't be voted on."))
        case .pollAnonymous:
            ErrorMessage(title: localized("Votes are anonymous"), body: localized("This poll doesn't show who voted."))
        case .voteFailed:
            ErrorMessage(title: localized("Vote not counted"), body: localized("Your vote didn't go through. Try again."))
        case .notPinnable:
            ErrorMessage(title: localized("Can't pin this"), body: localized("Only messages people wrote can be pinned."))
        case .tooManyPins:
            ErrorMessage(title: localized("Too many pinned messages"), body: localized("Unpin one to pin another."))
        case .pinFailed:
            ErrorMessage(title: localized("Pins not changed"), body: localized("Try again in a moment."))
        default:
            unknownMessage
        }
    }
}
