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
    static let tournamentWinner = "tournament-winner"
    static let tournamentJoin = "tournament-join"
    static let tournamentCreateTeam = "tournament-create-team"
    static let tournamentLeave = "tournament-leave"
    static let tournamentMore = "tournament-more"
    static let tournamentEdit = "tournament-edit"
    static let tournamentCancel = "tournament-cancel"
    static let tournamentOpenChat = "tournament-open-chat"
    static let tournamentStart = "tournament-start"
    static let tournamentInvite = "tournament-invite"
    static let tournamentReport = "tournament-report"
    /// The bracket, the standings table and the matches list, each containing its cells or rows.
    static let tournamentBracket = "tournament-bracket"
    static let tournamentStandings = "tournament-standings"
    static let tournamentMatches = "tournament-matches"
    /// The match sheet: both score fields and every action.
    static let matchScoreA = "match-score-a"
    static let matchScoreB = "match-score-b"
    static let matchReport = "match-report"
    static let matchConfirm = "match-confirm"
    static let matchDispute = "match-dispute"
    static let matchRecord = "match-record"
    static let matchWalkover = "match-walkover"
    /// The organiser's schedule: the link on the match sheet, then the time, the place, Save and Clear.
    static let matchSchedule = "match-schedule"
    static let matchScheduleTime = "match-schedule-time"
    static let matchLocationName = "match-location-name"
    static let matchScheduleSave = "match-schedule-save"
    static let matchScheduleClear = "match-schedule-clear"
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

    /// A match's cell in the bracket and its row in the list.
    static func match(_ id: String) -> String {
        "match-\(id)"
    }

    /// The walkover menu's item naming the winner.
    static func matchWalkoverWinner(_ entryID: String) -> String {
        "match-walkover-\(entryID)"
    }

    /// An entry's row of the standings.
    static func standing(_ entryID: String) -> String {
        "standing-\(entryID)"
    }
}
