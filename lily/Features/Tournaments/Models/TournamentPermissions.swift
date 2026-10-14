import Foundation

/// Who may do what on the tournament detail besides the matches (`MatchActions`) and the entry control
/// (`TournamentParticipation`), decided in one place so the menu, the header and the entries segment agree. Guests get
/// nothing. The organiser edits and cancels until the tournament is over, removes entries and is offered Start while
/// registration is open; the organiser and every entrant chat (while the flag is on) and invite until the deadline;
/// anyone signed in but the organiser reports and opens the organiser's profile; anyone signed in and not yet in may
/// join a team while registration is open, whatever the entry count, because joining a team adds no entry.
nonisolated struct TournamentPermissions: Equatable, Sendable {
    let canEdit: Bool
    let canCancel: Bool
    let canRemoveEntries: Bool
    let canOpenChat: Bool
    let canInvite: Bool
    let canReport: Bool
    /// Entries are members-level information, like a roster: shown to signed-in callers only.
    let showsEntries: Bool
    /// Start is offered to the organiser while registration is open, and enabled once enough entries are in.
    let showsStart: Bool
    let canStart: Bool
    /// Why Start is disabled, for the menu item's subtitle; `nil` while it is enabled or not offered.
    let startBlockedReason: String?
    /// The organiser's profile, when the caller may open it: signed in, and not the organiser themselves.
    let organizerProfile: UserProfileDestination?
    let canJoinTeams: Bool

    static let none = TournamentPermissions(canEdit: false,
                                            canCancel: false,
                                            canRemoveEntries: false,
                                            canOpenChat: false,
                                            canInvite: false,
                                            canReport: false,
                                            showsEntries: false,
                                            showsStart: false,
                                            canStart: false,
                                            startBlockedReason: nil,
                                            organizerProfile: nil,
                                            canJoinTeams: false)

    var showsMenu: Bool { canOpenChat || canEdit || canCancel || canInvite || canReport }
}

/// The rule itself; in an extension so the memberwise init above stays synthesized.
nonisolated extension TournamentPermissions {
    init(tournament: Tournament, userID: String?, now: Date, chatEnabled: Bool) {
        let role = TournamentRole(tournament: tournament, userID: userID)
        let signedIn = userID != nil
        let open = tournament.isRegistrationOpen(now: now)
        // The room's members: the organiser and every player in.
        let isInvolved = role.isOrganizer || tournament.hasEntered
        let canEdit = role.isOrganizer && !tournament.status.isOver
        let showsStart = role.isOrganizer && tournament.status == .registration
        let startBlockedReason: String? = showsStart && !tournament.canStart
            ? AppBranding.Tournaments.startNeeds(tournament.format.minimumEntriesToStart, teamSize: tournament.teamSize)
            : nil
        let organizerProfile: UserProfileDestination? = signedIn && !role.isOrganizer
            ? UserProfileDestination(userId: tournament.organizerUserId, displayName: tournament.organizerName)
            : nil
        self.init(canEdit: canEdit,
                  canCancel: canEdit,
                  canRemoveEntries: role.isOrganizer && tournament.status == .registration,
                  canOpenChat: chatEnabled && isInvolved,
                  canInvite: isInvolved && open,
                  canReport: signedIn && !role.isOrganizer,
                  showsEntries: signedIn,
                  showsStart: showsStart,
                  canStart: showsStart && tournament.canStart,
                  startBlockedReason: startBlockedReason,
                  organizerProfile: organizerProfile,
                  canJoinTeams: signedIn && !tournament.hasEntered && open && tournament.isTeam)
    }
}
