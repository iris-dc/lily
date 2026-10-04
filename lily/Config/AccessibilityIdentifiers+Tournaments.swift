import Foundation

/// Identifiers of the tournament screens; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The Explore carousel and its "See all".
    static let tournamentCarousel = "tournament-carousel"
    static let tournamentsSeeAll = "tournaments-see-all"
    static let tournamentsTypeFilter = "tournaments-type-filter"
    /// The detail: its Players | Bracket | Matches picker, the organiser line, the participation control and the menu.
    static let tournamentSection = "tournament-section"
    static let tournamentOrganizer = "tournament-organizer"
    static let tournamentJoin = "tournament-join"
    static let tournamentCreateTeam = "tournament-create-team"
    static let tournamentLeave = "tournament-leave"
    static let tournamentMore = "tournament-more"
    static let tournamentEdit = "tournament-edit"
    static let tournamentCancel = "tournament-cancel"
    static let tournamentOpenChat = "tournament-open-chat"
    /// The team-name sheet: its one field and its submit.
    static let tournamentTeamName = "tournament-team-name"
    static let tournamentTeamSubmit = "tournament-team-submit"
    /// The create and edit form; the group row is the event form's `createGroup`.
    static let tournamentName = "tournament-name"
    static let tournamentFormat = "tournament-format"
    static let tournamentTeamSize = "tournament-team-size"
    static let tournamentMaxEntries = "tournament-max-entries"
    static let tournamentDraws = "tournament-draws"
    static let tournamentDeadline = "tournament-deadline"
    static let tournamentVisibility = "tournament-visibility"
    static let tournamentLocationName = "tournament-location-name"
    static let tournamentSubmit = "tournament-submit"
    static let tournamentFormCancel = "tournament-form-cancel"

    /// A tournament's tile in the carousel and its card in a list.
    static func tournamentRow(_ id: String) -> String {
        "tournament-row-\(id)"
    }

    /// An entry on the Players segment, and its "Join team" button.
    static func entryRow(_ entryID: String) -> String {
        "entry-row-\(entryID)"
    }

    static func tournamentJoinTeam(_ entryID: String) -> String {
        "tournament-join-team-\(entryID)"
    }
}
