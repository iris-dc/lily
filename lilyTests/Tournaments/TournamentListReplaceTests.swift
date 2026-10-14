import Foundation
import Testing
@testable import lily

/// How a change made on a tournament detail reaches a list that does not hold the row: Home's Mine must take a
/// tournament the caller just entered on a detail pushed from a group's segment, and must ignore one that is none of
/// its business. The last two tests wire a detail the way Home does, its `onChange` being Mine's `replace`.
@MainActor
struct TournamentListReplaceTests {
    nonisolated private static let base = Date(timeIntervalSince1970: 1_800_000_000)
    nonisolated private static let secondsPerHour: TimeInterval = 3600
    private let harness = TournamentHarness()

    /// A tournament the caller has entered, `hours` after `base`; another user organises it.
    private func entered(_ id: String, hours: Double) -> Tournament {
        .fixture(id: id, startsAt: Self.base.addingTimeInterval(hours * Self.secondsPerHour), myEntryId: "e-\(id)")
    }

    /// Mine with `loaded` on screen.
    private func loadedMine(_ loaded: [Tournament]) async -> TournamentListViewModel {
        harness.repository.result = .success(loaded)
        let mine = harness.makeListViewModel(scope: .mine)
        await mine.load()
        return mine
    }

    /// A detail of `tournament`, loaded, answering through `mine.replace` as Home's stack wires it.
    private func detailOnHome(_ tournament: Tournament,
                              entries: [TournamentEntry] = [.fixture()],
                              replacingIn mine: TournamentListViewModel) async -> TournamentDetailViewModel {
        harness.repository.details[tournament.id] = .fixture(tournament: tournament, entries: entries)
        let destination = TournamentDestination(id: tournament.id, name: tournament.name)
        let detail = harness.makeDetailViewModel(for: destination, onChange: mine.replace)
        await detail.load()
        return detail
    }

    @Test func replaceInsertsATournamentTheCallerJustEnteredIntoMine() async {
        let mine = await loadedMine([entered("a", hours: 0), entered("c", hours: 2)])

        mine.replace(entered("b", hours: 1))
        await mine.loadIfStale()

        #expect(mine.tournaments.map(\.id) == ["a", "b", "c"], "placed by start")
        #expect(harness.repository.requestedScopes == [.mine], "the list shows the change itself and does not reload")
    }

    /// Mine lists what the caller organises or has entered; a change to anything else only tells the other lists.
    @Test func replaceOfATournamentNeitherHeldNorBelongingChangesOnlyTheVersion() async {
        let loaded = [entered("a", hours: 0), entered("c", hours: 2)]
        let mine = await loadedMine(loaded)
        let version = harness.changes.version

        mine.replace(.fixture(id: "x", startsAt: Self.base.addingTimeInterval(Self.secondsPerHour)))

        #expect(mine.tournaments == loaded)
        #expect(harness.changes.version == version + 1)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("Tournament x replaced in scope") })
    }

    /// The detail's answer changes the row without a list request, and Mine, having acknowledged its own change, asks
    /// nothing on its next appearance either.
    @Test func theDetailsAnswerReplacesTheRowOnHome() async {
        let organised = Tournament.fixture(id: "t", organizerUserId: TestFixtures.user.id)
        let mine = await loadedMine([organised])
        let detail = await detailOnHome(organised, replacingIn: mine)

        await detail.cancel()

        #expect(mine.tournaments.first?.status == .cancelled)
        await mine.loadIfStale()
        #expect(harness.repository.requestedScopes == [.mine], "Mine acknowledged its own change")
    }

    /// A leave answers the tournament without the caller's entry, and Mine lists only what the caller organises or has
    /// entered: the row goes, again without a list request.
    @Test func theDetailsAnswerDropsARowTheCallerLeftFromHome() async {
        let entry = TournamentEntry.fixture(id: "e-1", captainUserId: TestFixtures.user.id)
        let left = Tournament.fixture(id: "t", entryCount: 1, myEntryId: "e-1")
        let mine = await loadedMine([left])
        let detail = await detailOnHome(left, entries: [entry], replacingIn: mine)

        await detail.leave()

        #expect(mine.tournaments.isEmpty)
        #expect(harness.repository.requestedScopes.filter { $0 == .mine }.count == 1, "no list request")
    }
}
