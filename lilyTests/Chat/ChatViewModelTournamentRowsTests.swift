import Foundation
import Testing
@testable import lily

/// The tournament notes in a tournament's room: their copy (the start's by format, once the tournament is known; the
/// rest from the server's text), where they lead, and what a live one reloads.
@MainActor
struct ChatViewModelTournamentRowsTests {
    private let room = SportGroup.tournamentRoomFixture(id: "t", name: "Tuesday Table Tennis")
    private let started = ChatMessage.fixture(id: "s1", groupID: "t", kind: .tournamentStarted, text: nil, tournamentID: "t")
    private let result = ChatMessage.fixture(id: "s2",
                                             groupID: "t",
                                             kind: .matchResult,
                                             text: "Marta 3–1 Noor",
                                             tournamentID: "t",
                                             matchID: "r01p001")

    private func makeChat() async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([room])
        harness.cache.store(.fixture(groupID: "t", messages: [.fixture(id: "m1", groupID: "t")]), for: "t")
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: room))
    }

    @Test func theStartNamesTheFormatOnceTheTournamentLoadedAndFetchesItOnce() async {
        let (harness, viewModel) = await makeChat()
        harness.tournaments.details["t"] = .fixture(tournament: .fixture(id: "t", format: .roundRobin, status: .inProgress))
        #expect(viewModel.systemText(for: started) == "The tournament started")

        await viewModel.loadLinkedContent(for: started)
        await viewModel.loadLinkedContent(for: started)

        #expect(viewModel.systemText(for: started) == "The schedule is out" && harness.tournaments.fetchedIDs == ["t"])
        let (second, bracket) = await makeChat()
        second.tournaments.details["t"] = .fixture(tournament: .fixture(id: "t", format: .singleElimination, status: .inProgress))
        await bracket.loadLinkedContent(for: started)
        #expect(bracket.systemText(for: started) == "The bracket is out")
    }

    @Test func resultsDisputesAndTheWinnerShowTheServersTextOrAFallback() async {
        let (harness, viewModel) = await makeChat()
        #expect(viewModel.systemText(for: result) == "Marta 3–1 Noor")
        let silentResult = ChatMessage.fixture(id: "s3", kind: .matchResult, text: nil, tournamentID: "t")
        #expect(viewModel.systemText(for: silentResult) == "A result is in")
        #expect(viewModel.systemText(for: .fixture(id: "s4", kind: .matchDisputed, text: "Noor – Ayşe", tournamentID: "t"))
            == "Result disputed: Noor – Ayşe")
        let silentDispute = ChatMessage.fixture(id: "s5", kind: .matchDisputed, text: nil, tournamentID: "t")
        #expect(viewModel.systemText(for: silentDispute) == "Result disputed")
        #expect(viewModel.systemText(for: .fixture(id: "s6", kind: .tournamentCompleted, text: "Marta", tournamentID: "t"))
            == "Marta won the tournament")
        #expect(viewModel.systemText(for: .fixture(id: "s7", kind: .tournamentCompleted, text: nil, tournamentID: "t"))
            == "The tournament is over")
        await viewModel.loadLinkedContent(for: result)
        #expect(harness.tournaments.fetchedIDs.isEmpty, "only the start needs the tournament's format")
    }

    /// The room is the tournament, so its name is on hand; a result selects its match.
    @Test func aTournamentRowOpensTheTournamentWithItsMatchSelectedWithoutAFetch() async {
        let (harness, viewModel) = await makeChat()

        #expect(await viewModel.destination(for: result)
            == .tournament(TournamentDestination(id: "t", name: "Tuesday Table Tennis", matchID: "r01p001")))
        #expect(await viewModel.destination(for: started)
            == .tournament(TournamentDestination(id: "t", name: "Tuesday Table Tennis")))
        #expect(harness.tournaments.fetchedIDs.isEmpty && harness.errorCenter.current == nil)
        #expect(await viewModel.destination(for: .fixture(id: "x", kind: .matchResult, text: "a", tournamentID: nil)) == nil)
    }

    @Test func anUnavailableTournamentKeepsTheFallbackQuietly() async {
        let (harness, viewModel) = await makeChat()
        harness.tournaments.detailError = AppError.network

        await viewModel.loadLinkedContent(for: started)

        #expect(viewModel.systemText(for: started) == "The tournament started" && harness.errorCenter.current == nil)
        #expect(harness.chatLogs(.warning).contains { $0.hasPrefix("Tournament t behind a system row") })
    }

    @Test func aLiveTournamentNoteBumpsTheTournamentChangesAndNothingElse() async {
        let (harness, viewModel) = await makeChat()
        await viewModel.appear()
        let tournamentsBefore = harness.tournamentChanges.version
        let eventsBefore = harness.eventChanges.version

        harness.transport.post(.message(result), to: .room(groupID: "t", epoch: 1))
        await settle(until: { harness.tournamentChanges.version == tournamentsBefore + 1 })
        await harness.yield()

        #expect(harness.eventChanges.version == eventsBefore, "a tournament note changes no game")
        await viewModel.cancel()
    }
}
