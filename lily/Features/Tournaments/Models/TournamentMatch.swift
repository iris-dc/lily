import Foundation

/// One match as the backend answers it: `round` and `position` are 1-based and the id is `r<round>p<position>` with
/// two- and three-digit padding; a side is absent until its feeder match decided it; in single elimination the next
/// pointers say where the winner goes, and a bye carries its one entry as the winner already.
nonisolated struct TournamentMatch: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let tournamentId: String
    let round: Int
    let position: Int
    private(set) var entryAId: String?
    private(set) var entryBId: String?
    private(set) var status: MatchStatus
    private(set) var scoreA: Int?
    private(set) var scoreB: Int?
    private(set) var winnerEntryId: String?
    private(set) var isDisputed: Bool
    private(set) var scheduledAt: Date?
    private(set) var location: EventLocation?
    private(set) var reportedBy: String?
    private(set) var reportedAt: Date?
    private(set) var confirmedBy: String?
    private(set) var confirmedAt: Date?
    let nextMatchId: String?
    let nextSlot: MatchSlot?

    init(id: String,
         tournamentId: String,
         round: Int,
         position: Int,
         entryAId: String? = nil,
         entryBId: String? = nil,
         status: MatchStatus = .pending,
         scoreA: Int? = nil,
         scoreB: Int? = nil,
         winnerEntryId: String? = nil,
         isDisputed: Bool = false,
         scheduledAt: Date? = nil,
         location: EventLocation? = nil,
         reportedBy: String? = nil,
         reportedAt: Date? = nil,
         confirmedBy: String? = nil,
         confirmedAt: Date? = nil,
         nextMatchId: String? = nil,
         nextSlot: MatchSlot? = nil) {
        self.id = id
        self.tournamentId = tournamentId
        self.round = round
        self.position = position
        self.entryAId = entryAId
        self.entryBId = entryBId
        self.status = status
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.winnerEntryId = winnerEntryId
        self.isDisputed = isDisputed
        self.scheduledAt = scheduledAt
        self.location = location
        self.reportedBy = reportedBy
        self.reportedAt = reportedAt
        self.confirmedBy = confirmedBy
        self.confirmedAt = confirmedAt
        self.nextMatchId = nextMatchId
        self.nextSlot = nextSlot
    }

    /// A match the mock builds from the schedule's pairing, under its tournament.
    init(pairing: TournamentSchedule.Pairing, tournamentId: String) {
        self.init(id: pairing.id,
                  tournamentId: tournamentId,
                  round: pairing.round,
                  position: pairing.position,
                  entryAId: pairing.entryAId,
                  entryBId: pairing.entryBId,
                  status: pairing.status,
                  winnerEntryId: pairing.winnerEntryId,
                  nextMatchId: pairing.nextMatchId,
                  nextSlot: pairing.nextSlot)
    }

    var hasBothSides: Bool { entryAId != nil && entryBId != nil }
    var isDecided: Bool { status.isDecided }
    /// Whether a result may be taken: both sides known, not decided, the tournament's state being the caller's check.
    var isReadyForResult: Bool { hasBothSides && (status == .pending || status == .scheduled || status == .reported) }

    func contains(entryID: String?) -> Bool {
        entryID != nil && (entryAId == entryID || entryBId == entryID)
    }

    /// The side a winner's feeder match sends it into.
    func placing(_ entryID: String, in slot: MatchSlot) -> TournamentMatch {
        var copy = self
        switch slot {
        case .a: copy.entryAId = entryID
        case .b: copy.entryBId = entryID
        }
        return copy
    }

    /// A score one side reported, or the organiser recorded (then `confirmed` at once).
    func scored(_ scoreA: Int, _ scoreB: Int, by userID: String, confirmed: Bool, at date: Date) -> TournamentMatch {
        var copy = self
        copy.scoreA = scoreA
        copy.scoreB = scoreB
        copy.isDisputed = false
        if confirmed {
            copy.status = .confirmed
            copy.winnerEntryId = scoreA == scoreB ? nil : (scoreA > scoreB ? entryAId : entryBId)
            copy.confirmedBy = userID
            copy.confirmedAt = date
        } else {
            copy.status = .reported
            copy.reportedBy = userID
            copy.reportedAt = date
        }
        return copy
    }

    func confirming(by userID: String, at date: Date) -> TournamentMatch {
        guard let scoreA, let scoreB else { return self }
        return scored(scoreA, scoreB, by: userID, confirmed: true, at: date)
    }

    /// Back to pending with the dispute flagged; the scores stay for the organiser to look at.
    func disputing() -> TournamentMatch {
        var copy = self
        copy.status = .pending
        copy.isDisputed = true
        copy.reportedBy = nil
        copy.reportedAt = nil
        return copy
    }

    func walkover(winnerEntryId: String, by userID: String, at date: Date) -> TournamentMatch {
        var copy = self
        copy.status = .walkover
        copy.winnerEntryId = winnerEntryId
        copy.isDisputed = false
        copy.confirmedBy = userID
        copy.confirmedAt = date
        return copy
    }

    func scheduling(_ schedule: MatchSchedule) -> TournamentMatch {
        var copy = self
        copy.scheduledAt = schedule.scheduledAt
        copy.location = schedule.location
        if copy.status == .pending || copy.status == .scheduled {
            copy.status = schedule.scheduledAt == nil ? .pending : .scheduled
        }
        return copy
    }
}

/// A match's time and place, as `PUT .../schedule` takes them; both absent clears the schedule.
nonisolated struct MatchSchedule: Hashable, Codable, Sendable {
    let scheduledAt: Date?
    let location: EventLocation?

    init(scheduledAt: Date? = nil, location: EventLocation? = nil) {
        self.scheduledAt = scheduledAt
        self.location = location
    }
}

/// One row of a round robin's table, computed by the backend on every read.
nonisolated struct TournamentStanding: Identifiable, Hashable, Codable, Sendable {
    let entryId: String
    let rank: Int
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let scored: Int
    let conceded: Int
    let points: Int

    var id: String { entryId }
    var scoreDifference: Int { scored - conceded }
}

/// A tournament with everything on its screen: the entries in seed order, the matches by round and position once it
/// started, and the standings of a round robin in progress (empty for a bracket).
nonisolated struct TournamentDetail: Hashable, Codable, Sendable {
    private(set) var tournament: Tournament
    private(set) var entries: [TournamentEntry]
    private(set) var matches: [TournamentMatch]
    private(set) var standings: [TournamentStanding]

    init(tournament: Tournament,
         entries: [TournamentEntry] = [],
         matches: [TournamentMatch] = [],
         standings: [TournamentStanding] = []) {
        self.tournament = tournament
        self.entries = entries
        self.matches = matches
        self.standings = standings
    }

    var id: String { tournament.id }
    var myEntry: TournamentEntry? { tournament.myEntryId.flatMap(entry(id:)) }
    var registeredEntries: [TournamentEntry] { entries.filter(\.isRegistered) }

    func entry(id: String) -> TournamentEntry? {
        entries.first { $0.id == id }
    }

    func match(id: String) -> TournamentMatch? {
        matches.first { $0.id == id }
    }

    /// The entry the caller is in, from the roster rather than `myEntryId` (the mock's lists carry no caller).
    func entry(containing userID: String?) -> TournamentEntry? {
        entries.first { $0.contains(userID: userID) }
    }

    func replacing(tournament: Tournament) -> TournamentDetail {
        var copy = self
        copy.tournament = tournament
        return copy
    }

    func replacing(entries: [TournamentEntry]) -> TournamentDetail {
        var copy = self
        copy.entries = entries
        return copy
    }

    func replacing(matches: [TournamentMatch], standings: [TournamentStanding]) -> TournamentDetail {
        var copy = self
        copy.matches = matches
        copy.standings = standings
        return copy
    }
}
