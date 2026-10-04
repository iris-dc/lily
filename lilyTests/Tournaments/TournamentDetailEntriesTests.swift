import Foundation
import Testing
@testable import lily

/// Entering and leaving from the detail; every write refetches the detail, so the count and the caller's entry are the
/// backend's.
@MainActor
struct TournamentDetailEntriesTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    private func loaded(_ tournament: Tournament, entries: [TournamentEntry] = [.fixture()]) async -> TournamentDetailViewModel {
        harness.repository.details["t"] = .fixture(tournament: tournament, entries: entries)
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        return viewModel
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

        let second = TournamentHarness()
        second.repository.details["t"] = .fixture(tournament: .fixture(teamSize: 5, entryCount: 1), entries: [team])
        let joiner = second.makeDetailViewModel(for: destination)
        await joiner.load()
        await joiner.joinTeam(team)
        #expect(second.repository.teamJoins.map(\.entryID) == ["team-1"] && joiner.tournament?.myEntryId == "team-1")
    }

    @Test func aFullTeamIsNotOffered() async {
        let members = [EntryMember(userId: "a", displayName: "A"), EntryMember(userId: "b", displayName: "B")]
        let full = TournamentEntry.fixture(id: "full", members: members)
        let viewModel = await loaded(.fixture(teamSize: 2, entryCount: 1), entries: [full])
        #expect(!viewModel.canJoin(full))
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
    }

    @Test func theOrganiserRemovesAnEntry() async {
        let entry = TournamentEntry.fixture(id: "e1")
        let viewModel = await loaded(.fixture(entryCount: 1, organizerUserId: TestFixtures.user.id), entries: [entry])

        await viewModel.removeEntry(entry)

        #expect(harness.repository.removedEntries.map(\.entryID) == ["e1"] && viewModel.detail?.entries.isEmpty == true)
    }

    @Test func aRefusalReachesThePopupAndAnUnknownOutcomeIsNotSecondGuessed() async {
        harness.repository.actionError = AppError.tournamentFull
        let viewModel = await loaded(.fixture())

        await viewModel.join()

        #expect(harness.presentedError == .tournamentFull && viewModel.participation == .join)
        #expect(harness.logs(.error).contains { $0.contains("Join failed") })
    }

    @Test func aFailedRefetchAfterAWriteKeepsTheScreenQuiet() async {
        let viewModel = await loaded(.fixture(entryCount: 1))
        harness.repository.detailError = AppError.network

        await viewModel.join()

        #expect(harness.repository.joins.count == 1 && harness.presentedError == nil)
        #expect(harness.logs(.warning).contains { $0.contains("Could not refresh") })
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

/// Counts how often a view model offered the reminder permission.
@MainActor
final class SpyPushOptIn: PushOptIn {
    private(set) var offerCount = 0

    func offerReminders() async {
        offerCount += 1
    }
}
