import Foundation
import Testing
@testable import lily

/// Entering and leaving from the detail; every write refetches the detail, so the count and the caller's entry are the
/// backend's, and reloads Mine, so the Chats tab lists or drops the tournament's room at once.
@MainActor
struct TournamentDetailEntriesTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")
    /// The organiser who also plays, as `e1`, next to one other entry.
    private let organiserPlaying = Tournament.fixture(entryCount: 2, organizerUserId: TestFixtures.user.id, myEntryId: "e1")
    private let ownEntry = TournamentEntry.fixture(id: "e1", captainUserId: TestFixtures.user.id)
    private let otherEntry = TournamentEntry.fixture(id: "e2", name: "Dev", captainUserId: "u-2", seed: 2)

    private func loaded(_ tournament: Tournament, entries: [TournamentEntry] = [.fixture()]) async -> TournamentDetailViewModel {
        await harness.loadedDetailViewModel(tournament, entries: entries, for: destination)
    }

    @Test func joiningAnIndividualTournamentRefetchesAndOffersTheReminder() async {
        let pushOptIn = SpyPushOptIn()
        harness.repository.details["t"] = .fixture(tournament: .fixture(entryCount: 1))
        let viewModel = harness.makeDetailViewModel(for: destination, pushOptIn: pushOptIn)
        await viewModel.load()

        await viewModel.join()

        #expect(harness.repository.joins.map(\.teamName) == [nil])
        #expect(viewModel.tournament?.entryCount == 2 && viewModel.tournament?.hasEntered == true)
        #expect(viewModel.participation == .leave)
        #expect(harness.sink.tournaments.last?.entryCount == 2 && pushOptIn.offerCount == 1)
        #expect(harness.logs(.info).contains { $0.contains("joined as entry") })
        #expect(harness.repository.fetchedIDs.count == 2, "one load, one refetch")
        #expect(harness.groupRepository.requestedScopes == [.mine], "Mine reloads for the room the caller is now in")
    }

    @Test func creatingATeamSendsItsNameAndJoiningOneItsId() async {
        let team = TournamentEntry.fixture(id: "team-1",
                                           name: "Görli Giants",
                                           captainUserId: "seed-marta",
                                           members: [EntryMember(userId: "seed-marta", displayName: "Marta")])
        let viewModel = await loaded(.fixture(teamSize: 5, entryCount: 1), entries: [team])
        #expect(viewModel.participation == .createTeam && viewModel.canJoin(team))

        await viewModel.createTeam(named: "  Late Tackles ")
        #expect(harness.repository.joins.map(\.teamName) == ["Late Tackles"])
        #expect(viewModel.tournament?.entryCount == 2 && viewModel.participation == .leave)
        #expect(!viewModel.canJoin(team), "once in, no other team is offered")
        #expect(harness.groupRepository.requestedScopes == [.mine])

        let second = TournamentHarness()
        second.repository.details["t"] = .fixture(tournament: .fixture(teamSize: 5, entryCount: 1), entries: [team])
        let joiner = second.makeDetailViewModel(for: destination)
        await joiner.load()
        await joiner.joinTeam(team)
        #expect(second.repository.teamJoins.map(\.entryID) == ["team-1"] && joiner.tournament?.myEntryId == "team-1")
        #expect(second.groupRepository.requestedScopes == [.mine])
    }

    @Test func aFullTeamIsNotOffered() async {
        let members = [EntryMember(userId: "a", displayName: "A"), EntryMember(userId: "b", displayName: "B")]
        let full = TournamentEntry.fixture(id: "full", members: members)
        let viewModel = await loaded(.fixture(teamSize: 2, entryCount: 1), entries: [full])
        #expect(!viewModel.canJoin(full))
    }

    /// Joining a team adds no entry, so a tournament whose entries are all in still offers a seat on a team that has one.
    @Test func joinTeamStaysOfferedWhileATeamHasASeat() async {
        let half = TournamentEntry.fixture(id: "half", members: [EntryMember(userId: "a", displayName: "A")])
        let viewModel = await loaded(.fixture(teamSize: 2, maxEntries: 1, entryCount: 1), entries: [half])
        #expect(viewModel.participation == .full, "the primary control reads Full")
        #expect(viewModel.canJoin(half))
    }

    @Test func joinTeamIsNotOfferedOnceTheCallerIsInOrRegistrationClosed() async {
        let half = TournamentEntry.fixture(id: "half", members: [EntryMember(userId: "a", displayName: "A")])
        let entered = await loaded(.fixture(teamSize: 2, entryCount: 1, myEntryId: "other"), entries: [half])
        #expect(!entered.canJoin(half))

        let started = await loaded(.fixture(status: .inProgress, teamSize: 2, entryCount: 1), entries: [half])
        #expect(!started.canJoin(half))

        harness.identity.currentUserID = nil
        let guest = await loaded(.fixture(teamSize: 2, entryCount: 1), entries: [half])
        #expect(!guest.canJoin(half))
    }

    @Test func leavingSendsTheCallersEntryAndRefetches() async {
        let mine = TournamentEntry.fixture(id: "mine", captainUserId: TestFixtures.user.id)
        let viewModel = await loaded(.fixture(entryCount: 1, myEntryId: "mine"), entries: [mine])
        #expect(viewModel.participation == .leave)

        await viewModel.leave()

        let expected = FakeTournamentRepository.Leave(id: "t", entryID: "mine", userID: TestFixtures.user.id)
        #expect(harness.repository.leaves == [expected])
        #expect(viewModel.tournament?.hasEntered == false && viewModel.participation == .join)
        #expect(harness.logs(.info).contains { $0.contains("left (entry mine)") })
        #expect(harness.groupRepository.requestedScopes == [.mine], "Mine reloads for the room the caller left")
    }

    /// Mine's by-user index may still list the room right after the leave, so the room leaves Mine locally too; an
    /// organiser who also played keeps the room they own.
    @Test func leavingDropsTheRoomEvenWhenMineStillListsIt() async {
        await harness.loadGroups([.tournamentRoomFixture(id: "t"), .fixture(id: "g")])
        let mine = TournamentEntry.fixture(id: "mine", captainUserId: TestFixtures.user.id)
        let viewModel = await loaded(.fixture(entryCount: 1, myEntryId: "mine"), entries: [mine])

        await viewModel.leave()
        #expect(harness.groups.groups.map(\.id) == ["g"])

        let organiser = TournamentHarness()
        await organiser.loadGroups([.tournamentRoomFixture(id: "t")])
        let playing = Tournament.fixture(entryCount: 1, organizerUserId: TestFixtures.user.id, myEntryId: "mine")
        organiser.repository.details["t"] = .fixture(tournament: playing, entries: [mine])
        let own = organiser.makeDetailViewModel(for: destination)
        await own.load()
        await own.leave()
        #expect(organiser.repository.leaves.count == 1 && organiser.groups.groups.map(\.id) == ["t"])
    }

    @Test func theOrganiserRemovesAnEntry() async {
        let entry = TournamentEntry.fixture(id: "e1")
        let viewModel = await loaded(.fixture(entryCount: 1, organizerUserId: TestFixtures.user.id), entries: [entry])

        await viewModel.removeEntry(entry)

        #expect(harness.repository.removedEntries.map(\.entryID) == ["e1"] && viewModel.detail?.entries.isEmpty == true)
        #expect(harness.groupRepository.requestedScopes.isEmpty, "the organiser's own rooms are unchanged")
    }

    /// The backend clears `myEntryId` only when the removed entry held the caller: an organiser who plays keeps theirs.
    @Test func removingAnotherEntryKeepsMyEntryId() async {
        let viewModel = await loaded(organiserPlaying, entries: [ownEntry, otherEntry])

        await viewModel.removeEntry(otherEntry)

        #expect(viewModel.tournament?.myEntryId == "e1" && viewModel.detail?.entries.map(\.id) == ["e1"])
        #expect(viewModel.participation == .leave, "still in, so Leave rather than Join")
    }

    @Test func removingTheCallersOwnEntryClearsMyEntryId() async {
        let viewModel = await loaded(organiserPlaying, entries: [ownEntry, otherEntry])

        await viewModel.removeEntry(ownEntry)

        #expect(viewModel.tournament?.myEntryId == nil && viewModel.detail?.entries.map(\.id) == ["e2"])
        #expect(viewModel.participation == .join)
    }

    /// A refusal is an expected product state: the popup explains it, the log stays at warning, nothing is fetched again.
    @Test func refusalsLogAtWarning() async {
        harness.repository.actionError = AppError.tournamentFull
        let viewModel = await loaded(.fixture())

        await viewModel.join()

        #expect(harness.presentedError == .tournamentFull && viewModel.participation == .join)
        #expect(harness.logs(.warning).contains { $0.contains("Join for tournament t failed") })
        #expect(harness.logs(.error).isEmpty)
        #expect(harness.repository.fetchedIDs.count == 1, "a refusal refetches nothing")
        #expect(harness.groupRepository.requestedScopes.isEmpty, "a refused entry moves no room")
    }

    @Test func oneActionAtATime() async {
        harness.repository.holdsRequests = true
        harness.repository.details["t"] = .fixture()
        let viewModel = harness.makeDetailViewModel(for: destination)
        let load = Task { await viewModel.load() }
        await settle { harness.repository.fetchedIDs.count == 1 }
        harness.repository.releaseRequests()
        await load.value
        harness.repository.holdsRequests = true

        let first = Task { await viewModel.join() }
        await settle { viewModel.isBusy }
        await viewModel.join()
        harness.repository.releaseRequests()
        await first.value

        #expect(harness.repository.joins.count == 1)
    }
}
