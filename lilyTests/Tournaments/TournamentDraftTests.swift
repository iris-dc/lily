import Foundation
import Testing
@testable import lily

struct TournamentDraftTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aCompleteDraftHasNoIssues() {
        let draft = TournamentDraft.fixture(now: Self.now)
        #expect(draft.issues(now: Self.now).isEmpty && draft.isValid(now: Self.now))
        #expect(draft.resolvedAllowsDraws, "football draws by default")
        #expect(draft.effectiveVisibility == .public && !draft.isTeam)
    }

    @Test func issuesComeInFormOrder() {
        var draft = TournamentDraft(startsAt: Self.now, clientId: "id")
        draft.teamSize = 12
        draft.maxEntries = 1
        draft.registrationClosesAt = Self.now.addingTimeInterval(3600)
        draft.description = String(repeating: "x", count: AppConfig.Tournaments.descriptionMaxLength + 1)

        #expect(draft.issues(now: Self.now) == [.nameTooShort, .teamSizeOutOfRange, .maxEntriesOutOfRange, .startsAtTooSoon,
                                                .registrationClosesAfterStart, .locationNameMissing, .coordinateMissing,
                                                .descriptionTooLong])
    }

    @Test func textLimitsCountUTF16UnitsLikeTheBackend() {
        var draft = TournamentDraft.fixture(now: Self.now)
        draft.name = String(repeating: "😀", count: 30)
        #expect(draft.name.count == 30 && draft.name.wireLength == 60)
        #expect(!draft.issues(now: Self.now).contains(.nameTooLong))
        draft.name += "😀"
        #expect(draft.issues(now: Self.now).contains(.nameTooLong))
    }

    /// A round robin takes at most twelve entries; a bracket sixty-four.
    @Test func theEntriesCapFollowsTheFormat() {
        var draft = TournamentDraft.fixture(now: Self.now)
        draft.format = .roundRobin
        draft.maxEntries = 13
        #expect(draft.issues(now: Self.now) == [.maxEntriesOutOfRange])
        draft.format = .singleElimination
        #expect(draft.issues(now: Self.now).isEmpty)
        draft.maxEntries = 65
        #expect(draft.issues(now: Self.now) == [.maxEntriesOutOfRange])
        #expect(TournamentDraft.Rules.creation.entriesRange(for: .roundRobin) == 2...12)
        #expect(TournamentDraft.Rules.editing(entryCount: 5).entriesRange(for: .singleElimination) == 5...64)
    }

    /// An edit has no lead time and never fewer entries than are already in.
    @Test func editingRulesFloorTheEntriesAndDropTheLeadTime() {
        let tournament = Tournament.fixture(entryCount: 6, startsAt: Self.now.addingTimeInterval(60))
        var draft = TournamentDraft(editing: tournament)
        let rules = TournamentDraft.Rules.editing(entryCount: 6)
        #expect(draft.issues(now: Self.now, rules: rules).isEmpty)
        #expect(draft.issues(now: Self.now) == [.startsAtTooSoon], "the creation rules want fifteen minutes")
        draft.maxEntries = 5
        #expect(draft.issues(now: Self.now, rules: rules) == [.maxEntriesBelowEntries])
    }

    @Test func editingADraftRoundTripsThroughTheTournament() {
        let tournament = Tournament.fixture(allowsDraws: true, registrationClosesAt: Self.now.addingTimeInterval(1000))
        var draft = TournamentDraft(editing: tournament)
        #expect(draft.clientId == tournament.id && draft.allowsDraws == true)
        #expect(draft.registrationClosesAt == tournament.registrationClosesAt)
        draft.name = "Renamed"
        draft.registrationClosesAt = nil
        let updated = tournament.updating(with: draft, at: Self.now)
        #expect(updated.name == "Renamed" && updated.registrationClosesAt == nil && updated.id == tournament.id)
        #expect(updated.entryCount == tournament.entryCount && updated.updatedAt == Self.now)
    }

    @Test func makeTournamentIsTheStoredShapeOfADraft() {
        var draft = TournamentDraft.fixture(now: Self.now)
        draft.group = EventGroupRef(id: "g", name: "Kickers", visibility: .private, isDeleted: false)
        draft.teamSize = 5
        draft.allowsDraws = false
        let tournament = draft.makeTournament(organizerUserId: "u-1",
                                              organizerName: "You",
                                              coordinate: AppConfig.Location.mockCenter,
                                              now: Self.now)
        #expect(tournament.id == draft.clientId && tournament.visibility == .private && tournament.entryCount == 0)
        #expect(tournament.status == .registration && tournament.organizerUserId == "u-1" && !tournament.allowsDraws)
        #expect(tournament.group?.id == "g" && tournament.isTeam && tournament.createdAt == Self.now && !tournament.isListed)
    }

    @Test func theDeadlineProposalStaysAheadOfNow() {
        let soon = Self.now.addingTimeInterval(3600)
        #expect(TournamentDraft.proposedDeadline(before: soon, now: Self.now) == Self.now)
        let far = Self.now.addingTimeInterval(10 * 86_400)
        let lead = AppConfig.Tournaments.defaultDeadlineLead
        #expect(TournamentDraft.proposedDeadline(before: far, now: Self.now) == far.addingTimeInterval(-lead))
    }

    @Test func drawsDefaultPerType() {
        #expect(EventType.football.allowsDrawsByDefault && EventType.basketball.allowsDrawsByDefault)
        #expect(!EventType.tennis.allowsDrawsByDefault && !EventType.esports.allowsDrawsByDefault)
        #expect(!EventType.boardGames.allowsDrawsByDefault)
        var draft = TournamentDraft.fixture(now: Self.now)
        draft.type = .tennis
        #expect(!draft.resolvedAllowsDraws)
        draft.allowsDraws = true
        #expect(draft.resolvedAllowsDraws, "the organiser's choice wins over the default")
    }

    @Test func teamNamesAreJudgedAgainstTheBackendsLimits() {
        #expect(TeamNameIssue.issue(in: "A") == .tooShort && TeamNameIssue.issue(in: " ") == .tooShort)
        #expect(TeamNameIssue.issue(in: "Görli Giants") == nil)
        #expect(TeamNameIssue.issue(in: String(repeating: "x", count: 41)) == .tooLong)
    }
}
