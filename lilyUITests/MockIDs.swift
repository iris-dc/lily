/// The row identifiers of the mock fixtures: `AccessibilityIdentifiers.groupRow/tournamentRow/participantRow/memberRow`
/// over `MockGroupFixtures`, `MockTournamentFixtures` and the mock users, mirrored once because the target cannot
/// import the app, like `launchArguments`.
enum MockIDs {
    static let kickersRow = "group-row-mock-group-kickers"
    static let runnersRow = "group-row-mock-group-runners"
    static let padelRow = "group-row-mock-group-padel"
    static let basketballRow = "group-row-mock-group-basketball"
    static let volleyRow = "group-row-mock-group-volley"
    static let climbingRow = "group-row-mock-group-climbing"
    static let martaConversationRow = "group-row-mock-dm-mock-user-marta"
    static let jonasConversationRow = "group-row-mock-dm-mock-user-jonas"
    static let tableTennisRoomRow = "group-row-mock-tournament-table-tennis"
    static let padelOpenRoomRow = "group-row-mock-tournament-padel-open"
    static let kickersCupRow = "tournament-row-mock-tournament-kickers-cup"
    static let tableTennisRow = "tournament-row-mock-tournament-table-tennis"
    static let padelOpenRow = "tournament-row-mock-tournament-padel-open"
    static let sunsetSharedEventRow = "shared-event-row-mock-event-0"
    static let martaRow = "participant-row-mock-user-marta"
    static let jonasRow = "participant-row-mock-user-jonas"
    static let inesMemberRow = "member-row-mock-user-ines"
    static let devMemberRow = "member-row-mock-user-dev"
    static let martaMemberRow = "member-row-mock-user-marta"
    static let lucaMemberRow = "member-row-mock-user-luca"
    static let appleMemberRow = "member-row-mock-apple"
}
