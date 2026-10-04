import Foundation

/// The two tournaments of a mock run, with the rooms and rosters the group mock lists for them: the "Kickers Cup", a
/// 5-a-side bracket in Kreuzberg Kickers that the caller organises and has not entered, with four teams in; and
/// "Tuesday Table Tennis", Marta's round robin of six players, the caller among them, under way with three results in,
/// so the standings are on screen at launch. The caller is `callerMarker` in every stored row; the repository swaps
/// in whoever is signed in when it answers.
nonisolated enum MockTournamentFixtures {
    static let kickersCupID = "mock-tournament-kickers-cup"
    static let tableTennisID = "mock-tournament-table-tennis"
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

    /// The three results in: round one's matches.
    static let tableTennisResults = [Result(matchID: "r01p001", scoreA: 3, scoreB: 1),
                                     Result(matchID: "r01p002", scoreA: 3, scoreB: 2),
                                     Result(matchID: "r01p003", scoreA: 3, scoreB: 0)]

    private static let secondsPerHour = 3600.0
    private static let secondsPerDay = 86_400.0
    private static let kickersStartsInDays = 9.0
    private static let kickersDeadlineInDays = 7.0
    private static let kickersCreatedDaysAgo = 12.0
    private static let tableTennisStartedDaysAgo = 2.0
    private static let tableTennisCreatedDaysAgo = 16.0
    private static let tableTennisLastMessageHoursAgo = 3.0
    private static let entryIDPrefix = "01J9ENTRY"
    private static let entryIDDigits = 14

    static func make(now: Date) -> [TournamentDetail] {
        [kickersCup(now: now), tableTennis(now: now)]
    }

    /// The rooms the group mock lists for both tournaments: the caller owns the Kickers Cup's and is a member of the
    /// table-tennis one.
    static func rooms(now: Date) -> [SportGroup] {
        make(now: now).map { detail in
            let tournament = detail.tournament
            let isOrganizer = tournament.organizerUserId == callerMarker
            let callerEntry = detail.entry(containing: callerMarker)
            let joinedAt = isOrganizer ? tournament.createdAt : (callerEntry?.createdAt ?? tournament.createdAt)
            let lastMessageAt = now.addingTimeInterval(-tableTennisLastMessageHoursAgo * secondsPerHour)
            return room(for: tournament,
                        organizerName: tournament.organizerName,
                        memberCount: playerCount(of: detail),
                        membership: GroupMembership(role: isOrganizer ? .owner : .member,
                                                    joinedAt: joinedAt,
                                                    lastReadMessageId: MockChatFixtures.newestMessageID(for: tournament.id)),
                        lastMessageId: MockChatFixtures.newestMessageID(for: tournament.id),
                        lastMessageAt: tournament.id == tableTennisID ? lastMessageAt : nil)
        }
    }

    /// A tournament's room as the backend shapes one: under the tournament's id, named after it, its visibility and
    /// type, the organiser as owner, `maxEntries * teamSize + 1` seats, no group powers.
    static func room(for tournament: Tournament,
                     organizerName: String,
                     memberCount: Int,
                     membership: GroupMembership?,
                     lastMessageId: String? = nil,
                     lastMessageAt: Date? = nil) -> SportGroup {
        SportGroup(id: tournament.id,
                   name: tournament.name,
                   visibility: tournament.visibility,
                   type: tournament.type,
                   ownerName: organizerName,
                   memberCount: memberCount,
                   maxMembers: tournament.maxEntries * tournament.teamSize + 1,
                   channelEpoch: tournament.channelEpoch,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageId: lastMessageId,
                   lastMessageAt: lastMessageAt,
                   createdAt: tournament.createdAt,
                   membership: membership,
                   kind: .tournament)
    }

    /// The other members of a tournament's room (never the caller): every player in, and the organiser when they do
    /// not play. Oldest first.
    static func roster(for tournamentID: String, now: Date) -> [GroupMember] {
        guard let detail = make(now: now).first(where: { $0.id == tournamentID }) else { return [] }
        var members = detail.entries.flatMap { entry in
            entry.members.filter { $0.userId != callerMarker }.map {
                GroupMember(userId: $0.userId, displayName: $0.displayName, role: .member, joinedAt: entry.createdAt)
            }
        }
        let organizer = detail.tournament
        if organizer.organizerUserId != callerMarker, !members.contains(where: { $0.userId == organizer.organizerUserId }) {
            members.insert(GroupMember(userId: organizer.organizerUserId,
                                       displayName: organizer.organizerName,
                                       role: .owner,
                                       joinedAt: organizer.createdAt),
                           at: 0)
        }
        return members
    }

    /// Sortable like a ULID, in registration order within a tournament.
    static func entryID(tournamentID: String, index: Int) -> String {
        let code = tournamentID == kickersCupID ? "KC" : "TT"
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
        var matches = TournamentSchedule.pairings(format: .roundRobin, seeds: entries.map(\.id)).map {
            TournamentMatch(pairing: $0, tournamentId: tableTennisID)
        }
        for result in tableTennisResults {
            guard let index = matches.firstIndex(where: { $0.id == result.matchID }) else { continue }
            matches[index] = matches[index].scored(result.scoreA, result.scoreB, by: organizerID, confirmed: true, at: startedAt)
        }
        let tournament = Tournament(id: tableTennisID,
                                    name: "Tuesday Table Tennis",
                                    description: "Best of five every Tuesday evening until everyone has played everyone.",
                                    type: .tableTennis,
                                    format: .roundRobin,
                                    status: .inProgress,
                                    maxEntries: 8,
                                    entryCount: entries.count,
                                    startsAt: startedAt,
                                    location: EventLocation(name: "Prenzlauer Berg Sports Hall",
                                                            coordinate: coordinate(offset: (0.9, 0.2))),
                                    organizerUserId: organizerID,
                                    organizerName: tableTennisOrganizer,
                                    startedAt: startedAt,
                                    createdAt: createdAt)
        return TournamentDetail(tournament: tournament,
                                entries: entries,
                                matches: matches,
                                standings: RoundRobinStandings.compute(entries: entries, matches: matches))
    }

    private static func coordinate(offset: (lat: Double, lon: Double)) -> Coordinate {
        let center = AppConfig.Location.mockCenter
        let spread = AppConfig.Location.fixtureSpreadDegrees
        return Coordinate(latitude: center.latitude + offset.lat * spread, longitude: center.longitude + offset.lon * spread)
    }
}
