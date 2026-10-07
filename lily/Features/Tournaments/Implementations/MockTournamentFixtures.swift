import Foundation

/// The tournaments of a mock run, with the rooms and rosters the group mock lists for them: the "Kickers Cup", a
/// 5-a-side bracket in Kreuzberg Kickers that the caller organises and has not entered, with four teams in; "Tuesday
/// Table Tennis", Marta's round robin of six players, the caller among them, under way with three results in (so the
/// standings are on screen at launch), a score Jonas reported against the caller (so Confirm and Dispute are a tap
/// away), a disputed match for the organiser and the caller's next match scheduled an hour ahead (the inbox's match
/// reminder names it); and Noor's private "Padel Open" (`MockTournamentFixtures+PadelOpen.swift`), which the caller is
/// invited into and not in. The caller is `callerMarker` in every stored row; the repository swaps in whoever is signed
/// in when it answers.
nonisolated enum MockTournamentFixtures {
    static let kickersCupID = "mock-tournament-kickers-cup"
    static let tableTennisID = "mock-tournament-table-tennis"
    /// Every fixture tournament, in the order `make(now:)` returns them.
    static var ids: [String] { [kickersCupID, tableTennisID, padelOpenID] }
    /// Stands for the caller wherever a fixture names them; `MockTournamentRepository.resolved` replaces it.
    static let callerMarker = "mock-caller"
    static let tableTennisOrganizer = "Marta"
    /// The caller's seed in the table-tennis fixture (third to register).
    static let callerTableTennisSeed = 3

    /// The teams of the Kickers Cup in registration order: the captain first, then the teammates in.
    static let kickersTeams: [(name: String, players: [String])] = [
        ("Görli Giants", ["Marta", "Jonas", "Dev", "Ayşe", "Sam"]),
        ("Canal Side FC", ["Aiko", "Noor", "Tom"]),
        ("Late Tackles", ["Luca", "Ines"]),
        ("Hasenheide United", ["Priya"]),
    ]
    /// The players of Tuesday Table Tennis in registration order; the caller is `callerMarker`.
    static let tableTennisPlayers = ["Marta", "Jonas", callerMarker, "Ayşe", "Dev", "Noor"]
    /// A result the organiser recorded: the match and both scores.
    struct Result {
        let matchID: String
        let scoreA: Int
        let scoreB: Int
    }

    /// A score one side reported, by the reporter's name.
    struct Report {
        let matchID: String
        let scoreA: Int
        let scoreB: Int
        let by: String
    }

    /// The three results in: round one's matches.
    static let tableTennisResults = [Result(matchID: "r01p001", scoreA: 3, scoreB: 1),
                                     Result(matchID: "r01p002", scoreA: 3, scoreB: 2),
                                     Result(matchID: "r01p003", scoreA: 3, scoreB: 0)]
    /// Round two: Jonas reported his win over the caller, who has yet to confirm it.
    static let tableTennisReport = Report(matchID: "r02p003", scoreA: 3, scoreB: 2, by: "Jonas")
    /// Round two: Noor reported her win over Ayşe, who disputed it; open again with the flag and without the score, for
    /// Marta to decide.
    static let tableTennisDispute = Report(matchID: "r02p002", scoreA: 3, scoreB: 1, by: "Noor")
    /// Round three: the caller's match against Dev, scheduled `AppConfig.Inbox.mockReminderLead` ahead at the hall, so
    /// the Matches list shows a time and a place and the inbox's match reminder has a match to name.
    static let tableTennisScheduledMatchID = "r03p002"
    static let tableTennisLocation = EventLocation(name: "Prenzlauer Berg Sports Hall",
                                                   coordinate: coordinate(offset: (0.9, 0.2)))

    /// Shared with `MockTournamentFixtures+PadelOpen.swift`, hence not private.
    static let secondsPerHour = 3600.0
    static let secondsPerDay = 86_400.0
    private static let kickersStartsInDays = 9.0
    private static let kickersDeadlineInDays = 7.0
    private static let kickersCreatedDaysAgo = 12.0
    private static let tableTennisStartedDaysAgo = 2.0
    private static let tableTennisReportedDaysAgo = 1.0
    private static let tableTennisCreatedDaysAgo = 16.0
    static let tableTennisLastMessageHoursAgo = 3.0
    private static let entryIDPrefix = "01J9ENTRY"
    private static let entryIDDigits = 14

    static func make(now: Date) -> [TournamentDetail] {
        [kickersCup(now: now), tableTennis(now: now), padelOpen(now: now)]
    }

    /// Sortable like a ULID, in registration order within a tournament.
    static func entryID(tournamentID: String, index: Int) -> String {
        let code = switch tournamentID {
        case kickersCupID: "KC"
        case padelOpenID: "PO"
        default: "TT"
        }
        return entryIDPrefix + code + String(format: "%0\(entryIDDigits)d", index)
    }

    /// The organiser counts as a room member when they do not play; every player in counts once.
    static func playerCount(of detail: TournamentDetail) -> Int {
        let players = detail.entries.reduce(0) { $0 + $1.memberCount }
        return detail.entry(containing: detail.tournament.organizerUserId) == nil ? players + 1 : players
    }

    private static func kickersCup(now: Date) -> TournamentDetail {
        let createdAt = now.addingTimeInterval(-kickersCreatedDaysAgo * secondsPerDay)
        let entries = kickersTeams.enumerated().map { index, team in
            TournamentEntry(id: entryID(tournamentID: kickersCupID, index: index),
                            tournamentId: kickersCupID,
                            name: team.name,
                            captainUserId: MockGroupFixtures.memberID(for: team.players[0]),
                            members: team.players.map {
                                EntryMember(userId: MockGroupFixtures.memberID(for: $0), displayName: $0)
                            },
                            seed: index + 1,
                            createdAt: createdAt.addingTimeInterval(Double(index + 1) * secondsPerDay))
        }
        let tournament = Tournament(id: kickersCupID,
                                    name: "Kickers Cup",
                                    description: "Eight teams, one evening, winner takes the Görli trophy. Bibs provided.",
                                    type: .football,
                                    format: .singleElimination,
                                    teamSize: 5,
                                    maxEntries: 8,
                                    entryCount: entries.count,
                                    // Football's default, as the backend fills it; a knockout refuses a draw regardless.
                                    allowsDraws: true,
                                    startsAt: now.addingTimeInterval(kickersStartsInDays * secondsPerDay),
                                    registrationClosesAt: now.addingTimeInterval(kickersDeadlineInDays * secondsPerDay),
                                    location: EventLocation(name: "Görlitzer Park pitch",
                                                            coordinate: coordinate(offset: (0.4, -0.5))),
                                    organizerUserId: callerMarker,
                                    organizerName: AppBranding.Tournaments.Create.mockOrganizerName,
                                    group: MockGroupFixtures.ref(for: MockGroupFixtures.kickersID),
                                    createdAt: createdAt)
        return TournamentDetail(tournament: tournament, entries: entries)
    }

    private static func tableTennis(now: Date) -> TournamentDetail {
        let createdAt = now.addingTimeInterval(-tableTennisCreatedDaysAgo * secondsPerDay)
        let startedAt = now.addingTimeInterval(-tableTennisStartedDaysAgo * secondsPerDay)
        let entries = tableTennisPlayers.enumerated().map { index, player in
            let userID = player == callerMarker ? callerMarker : MockGroupFixtures.memberID(for: player)
            let name = player == callerMarker ? AppBranding.Tournaments.Create.mockOrganizerName : player
            return TournamentEntry(id: entryID(tournamentID: tableTennisID, index: index),
                                   tournamentId: tableTennisID,
                                   name: name,
                                   captainUserId: userID,
                                   members: [EntryMember(userId: userID, displayName: name)],
                                   seed: index + 1,
                                   createdAt: createdAt.addingTimeInterval(Double(index + 1) * secondsPerDay))
        }
        let organizerID = MockGroupFixtures.memberID(for: tableTennisOrganizer)
        let matches = tableTennisMatches(entries: entries, organizerID: organizerID, startedAt: startedAt, now: now)
        let tournament = Tournament(id: tableTennisID,
                                    name: "Tuesday Table Tennis",
                                    description: "Best of five every Tuesday evening until everyone has played everyone.",
                                    type: .tableTennis,
                                    format: .roundRobin,
                                    status: .inProgress,
                                    maxEntries: 8,
                                    entryCount: entries.count,
                                    startsAt: startedAt,
                                    location: tableTennisLocation,
                                    organizerUserId: organizerID,
                                    organizerName: tableTennisOrganizer,
                                    startedAt: startedAt,
                                    createdAt: createdAt)
        return TournamentDetail(tournament: tournament,
                                entries: entries,
                                matches: matches,
                                standings: RoundRobinStandings.compute(entries: entries, matches: matches))
    }

    /// The round robin's matches: the organiser's three results, Jonas's report, the disputed one and the caller's
    /// scheduled next match.
    private static func tableTennisMatches(entries: [TournamentEntry],
                                           organizerID: String,
                                           startedAt: Date,
                                           now: Date) -> [TournamentMatch] {
        let reportedAt = now.addingTimeInterval(-tableTennisReportedDaysAgo * secondsPerDay)
        var matches = TournamentSchedule.pairings(format: .roundRobin, seeds: entries.map(\.id)).map {
            TournamentMatch(pairing: $0, tournamentId: tableTennisID)
        }
        for result in tableTennisResults {
            guard let index = matches.firstIndex(where: { $0.id == result.matchID }) else { continue }
            matches[index] = matches[index].recording(result.scoreA, result.scoreB, by: organizerID, at: startedAt)
        }
        for (report, disputed) in [(tableTennisReport, false), (tableTennisDispute, true)] {
            guard let index = matches.firstIndex(where: { $0.id == report.matchID }) else { continue }
            let reporter = MockGroupFixtures.memberID(for: report.by)
            let reported = matches[index].reporting(report.scoreA, report.scoreB, by: reporter, at: reportedAt)
            matches[index] = disputed ? reported.disputing() : reported
        }
        if let index = matches.firstIndex(where: { $0.id == tableTennisScheduledMatchID }) {
            let schedule = MatchSchedule(scheduledAt: now.addingTimeInterval(AppConfig.Inbox.mockReminderLead),
                                         location: tableTennisLocation)
            matches[index] = matches[index].scheduling(schedule)
        }
        return matches
    }

    static func coordinate(offset: (lat: Double, lon: Double)) -> Coordinate {
        .aroundMockCenter(lat: offset.lat, lon: offset.lon)
    }
}
