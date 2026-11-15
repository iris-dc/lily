import Foundation

/// The fourth fixture: Ines's "Moabit Badminton Open", a public singles knockout just announced with nobody entered
/// yet, so the detail's empty entries state (and the segment slot it shares with the loading spinner) is reachable on
/// a mock run. The caller is not in it; it lists on Explore after the Kickers Cup (it starts later and sits a touch
/// further from the demo centre). A file of its own, like the Padel Open, so the fixture enum stays under the limits.
nonisolated extension MockTournamentFixtures {
    static let badmintonOpenID = "mock-tournament-badminton-open"
    static let badmintonOpenOrganizer = "Ines"
    private static let badmintonOpenStartsInDays = 11.0
    private static let badmintonOpenDeadlineInDays = 10.0
    private static let badmintonOpenCreatedDaysAgo = 1.0

    static func badmintonOpen(now: Date) -> TournamentDetail {
        let tournament = Tournament(id: badmintonOpenID,
                                    name: "Moabit Badminton Open",
                                    description: "Singles knockout on the hall's four courts. Shuttles provided.",
                                    type: .badminton,
                                    format: .singleElimination,
                                    maxEntries: 8,
                                    startsAt: now.addingTimeInterval(badmintonOpenStartsInDays * .day),
                                    registrationClosesAt: now.addingTimeInterval(badmintonOpenDeadlineInDays * .day),
                                    location: EventLocation(name: "Sporthalle Moabit",
                                                            coordinate: coordinate(offset: (-0.6, 0.3))),
                                    organizerUserId: MockGroupFixtures.memberID(for: badmintonOpenOrganizer),
                                    organizerName: badmintonOpenOrganizer,
                                    createdAt: now.addingTimeInterval(-badmintonOpenCreatedDaysAgo * .day))
        return TournamentDetail(tournament: tournament)
    }
}
