import Foundation

/// The third fixture: Noor's "Padel Open", a private singles round robin in registration with four players in, which
/// the caller is invited into (`MockInboxFixtures`) and not in. Private, so it never reaches Explore and nothing but
/// the accepted invite puts it on Home; a file of its own so the main fixture file stays under the length limit.
nonisolated extension MockTournamentFixtures {
    static let padelOpenID = "mock-tournament-padel-open"
    static let padelOpenName = "Padel Open"
    static let padelOpenOrganizer = "Noor"
    /// The players in registration order; the organiser plays too.
    static let padelOpenPlayers = ["Noor", "Aiko", "Sam", "Tom"]
    private static let padelOpenStartsInDays = 12.0
    private static let padelOpenCreatedDaysAgo = 3.0

    static func padelOpen(now: Date) -> TournamentDetail {
        let createdAt = now.addingTimeInterval(-padelOpenCreatedDaysAgo * secondsPerDay)
        let entries = padelOpenPlayers.enumerated().map { index, player in
            let userID = MockGroupFixtures.memberID(for: player)
            return TournamentEntry(id: entryID(tournamentID: padelOpenID, index: index),
                                   tournamentId: padelOpenID,
                                   name: player,
                                   captainUserId: userID,
                                   members: [EntryMember(userId: userID, displayName: player)],
                                   seed: index + 1,
                                   createdAt: createdAt.addingTimeInterval(Double(index + 1) * secondsPerHour))
        }
        let tournament = Tournament(id: padelOpenID,
                                    name: padelOpenName,
                                    description: "Singles, best of three, invited players only.",
                                    type: .padel,
                                    format: .roundRobin,
                                    visibility: .private,
                                    maxEntries: 8,
                                    entryCount: entries.count,
                                    startsAt: now.addingTimeInterval(padelOpenStartsInDays * secondsPerDay),
                                    location: EventLocation(name: "Padel Court Mitte",
                                                            coordinate: coordinate(offset: (0.6, 0.4))),
                                    organizerUserId: MockGroupFixtures.memberID(for: padelOpenOrganizer),
                                    organizerName: padelOpenOrganizer,
                                    createdAt: createdAt)
        return TournamentDetail(tournament: tournament, entries: entries)
    }
}
