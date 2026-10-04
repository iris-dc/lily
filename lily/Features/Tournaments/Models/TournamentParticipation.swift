import Foundation

/// Who the caller is to a tournament, decided from the tournament and the caller's id. The organiser's role wins over
/// an entry of their own (an organiser may also play); `TournamentParticipation` reads the entry separately.
nonisolated enum TournamentRole: Equatable, Sendable {
    case guest
    case organizer
    case entrant(entryID: String)
    case outsider

    init(tournament: Tournament, userID: String?) {
        guard let userID else {
            self = .guest
            return
        }
        if tournament.isOrganized(by: userID) {
            self = .organizer
        } else if let entryID = tournament.myEntryId {
            self = .entrant(entryID: entryID)
        } else {
            self = .outsider
        }
    }

    var isOrganizer: Bool { self == .organizer }
    var isGuest: Bool { self == .guest }
}

/// What the tournament detail's primary control is. Decided in one place so the control and its tests agree; the
/// analogue of `Participation`. The organiser's own actions (edit, start, cancel) live in the menu.
nonisolated enum TournamentParticipation: Equatable, Sendable {
    /// Guests see no control; entering needs an account.
    case hidden
    /// An individual tournament open for entries.
    case join
    /// A team tournament open for entries: the caller names a team (joining one is on its row).
    case createTeam
    /// The caller is in and may still get out.
    case leave
    /// The caller is in and the tournament has moved on: nothing to do here.
    case entered
    /// The tournament started, ended or passed its deadline without the caller.
    case registrationClosed
    /// Every place is taken and the caller is not in.
    case full

    init(tournament: Tournament, userID: String?, now: Date) {
        guard userID != nil else {
            self = .hidden
            return
        }
        if tournament.hasEntered {
            self = tournament.isRegistrationOpen(now: now) ? .leave : .entered
        } else if !tournament.isRegistrationOpen(now: now) {
            self = .registrationClosed
        } else if tournament.isFull {
            self = .full
        } else {
            self = tournament.isTeam ? .createTeam : .join
        }
    }

    /// Whether "Join team" shows on an open team's row: the caller may enter and the team has room.
    var offersJoiningATeam: Bool { self == .createTeam }
}
