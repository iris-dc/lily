import Foundation

/// Copy for tournaments; `message(for:)` routes exactly those cases here. Two switches, so neither grows past the
/// complexity limit: the tournament itself, then entering and playing it.
nonisolated extension ErrorMessageMapper {
    static func tournamentMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .tournamentsUnavailable:
            ErrorMessage(title: localized("Tournaments unavailable"),
                         body: localized("We couldn't load tournaments right now. Pull to refresh in a moment."))
        case .tournamentNotFound:
            ErrorMessage(title: localized("Tournament not found"), body: localized("This tournament is no longer available."))
        case .tournamentCreationFailed:
            ErrorMessage(title: localized("Couldn't create your tournament"),
                         body: localized("Check the details and try again in a moment."))
        case .tournamentUpdateFailed:
            ErrorMessage(title: localized("Couldn't save your changes"),
                         body: localized("Check the details and try again in a moment."))
        case .tournamentActionFailed:
            ErrorMessage(title: localized("Couldn't update the tournament"), body: localized("Please try again in a moment."))
        case .notOrganizer:
            ErrorMessage(title: localized("Not your tournament"), body: localized("Only the organiser can do that."))
        case .tournamentLocked:
            ErrorMessage(title: localized("Tournament has started"),
                         body: localized("Only the name, description and place can change now."))
        case .tournamentLimit:
            tournamentLimitMessage
        default:
            entryMessage(for: error)
        }
    }

    private static var tournamentLimitMessage: ErrorMessage {
        let limit = AppConfig.Tournaments.maxOrganizedOpen
        return ErrorMessage(title: localized("Too many tournaments"),
                            body: localized("You can run at most \(limit) open tournaments. Finish or cancel one first."))
    }

    /// Entering, leaving and the matches.
    private static func entryMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .registrationClosed:
            ErrorMessage(title: localized("Registration closed"), body: localized("This tournament no longer takes entries."))
        case .tournamentFull:
            ErrorMessage(title: localized("Tournament is full"), body: localized("Every place is taken. Try another tournament."))
        case .alreadyEntered:
            ErrorMessage(title: localized("You're already in"), body: localized("You have already entered this tournament."))
        case .teamFull:
            ErrorMessage(title: localized("Team is full"),
                         body: localized("This team has all its players. Join another one or create your own."))
        case .entryNotFound:
            ErrorMessage(title: localized("Entry not found"), body: localized("This team is no longer in the tournament."))
        case .notEnoughEntries:
            ErrorMessage(title: localized("Not enough entries"),
                         body: localized("More teams or players need to enter before it can start."))
        case .notInMatch:
            ErrorMessage(title: localized("Not your match"),
                         body: localized("Only the players of a match can report its result."))
        case .matchNotReady:
            ErrorMessage(title: localized("Match not ready"),
                         body: localized("This match has no result to take yet, or is already decided."))
        case .drawNotAllowed:
            ErrorMessage(title: localized("No draws here"),
                         body: localized("This tournament doesn't allow a draw. Enter a winner."))
        default:
            unknownMessage
        }
    }
}
