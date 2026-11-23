import Foundation
import Testing
@testable import lily

/// The game or tournament a system row names is fetched once and worded in, a gone one is remembered, and where a tap
/// leads is answered to the room, never reported.
@MainActor
struct SystemRowContentTests {
    private let events: FakeEventRepository
    private let tournaments: FakeTournamentRepository
    private let eventChanges: ChangeTracker
    private let tournamentChanges: ChangeTracker
    private let logger: SpyLogger
    private let content: SystemRowContent

    private let eventRow = ChatMessage.fixture(id: "s1", senderName: "Marta", kind: .eventCreated, text: nil, eventID: "e")
    private let game = SportEvent.fixture(id: "e", title: "Sunday 5-a-side")
    private let started = ChatMessage.fixture(id: "s2", kind: .tournamentStarted, text: nil, tournamentID: "t")
    private let roomName = "Tuesday Table Tennis"

    init() {
        let events = FakeEventRepository()
        let tournaments = FakeTournamentRepository()
        let eventChanges = ChangeTracker()
        let tournamentChanges = ChangeTracker()
        let logger = SpyLogger()
        self.events = events
        self.tournaments = tournaments
        self.eventChanges = eventChanges
        self.tournamentChanges = tournamentChanges
        self.logger = logger
        content = SystemRowContent(links: SystemRowLinks(events: events,
                                                         tournaments: tournaments,
                                                         eventChanges: eventChanges,
                                                         tournamentChanges: tournamentChanges),
                                   groupID: "g",
                                   logger: logger)
    }

    @Test func anEventRowReadsTheFallbackUntilTheGameLoadedAndAsksOnce() async {
        events.result = .success([game])
        #expect(content.text(for: eventRow) == "Marta created an event")

        await content.load(for: eventRow)
        await content.load(for: eventRow)

        #expect(events.fetchedEventIDs == ["e"])
        #expect(content.text(for: eventRow) == "Marta created Sunday 5-a-side")
    }

    @Test func aGoneGameIsRememberedAndAskedForNoMore() async {
        events.thrownError = AppError.eventNotFound

        await content.load(for: eventRow)
        await content.load(for: eventRow)

        #expect(events.fetchedEventIDs == ["e"])
        #expect(content.linked.unavailableEventIDs == ["e"])
        #expect(warnings(prefixed: "Event e behind a system row in group g is unavailable").count == 1)
        #expect(content.text(for: eventRow) == "Marta created an event")
    }

    @Test func aTransientFailureLeavesTheRowToAskAgain() async {
        events.thrownError = AppError.network

        await content.load(for: eventRow)
        await content.load(for: eventRow)

        #expect(events.fetchedEventIDs == ["e", "e"])
        #expect(content.linked.unavailableEventIDs.isEmpty)
        #expect(warnings(prefixed: "Event e behind a system row").count == 2)

        events.thrownError = nil
        events.result = .success([game])
        await content.load(for: eventRow)
        #expect(content.text(for: eventRow) == "Marta created Sunday 5-a-side")
    }

    @Test func aGameDestinationIsFetchedAndAFailureIsAnsweredNotLogged() async {
        events.thrownError = AppError.eventNotFound
        if case .failure(let error) = await content.destination(for: eventRow, roomName: roomName) {
            #expect(error as? AppError == .eventNotFound)
        } else {
            Issue.record("a gone game is answered as a failure")
        }
        #expect(logger.messages(in: .chat).isEmpty, "the room decides what the caller sees")

        events.thrownError = nil
        events.result = .success([game])
        #expect(await opened(eventRow) == .event(game))
        #expect(events.fetchedEventIDs == ["e", "e"])
    }

    /// A note about the room's own game (its id is the room's) opens the info button's push — by id and name,
    /// `.fromChat` so the detail offers no chat back — answered without a fetch (the pushed loader fetches on
    /// arrival); any other game keeps the by-value push.
    @Test func aNoteAboutTheRoomsOwnGameOpensItFromChatWithoutAFetch() async {
        let ownRow = ChatMessage.fixture(id: "s9", senderName: "Marta", kind: .eventCreated, text: nil, eventID: "g")

        let destination = await opened(ownRow)

        #expect(destination == .eventRoom(EventDestination(id: "g", name: roomName, context: .fromChat)))
        #expect(events.fetchedEventIDs.isEmpty, "the destination is answered without a fetch; the loader fetches on arrival")
    }

    @Test func aTournamentNoteOpensTheTournamentWithoutAFetch() async {
        let note = await opened(started)
        #expect(note == .tournament(TournamentDestination(id: "t", name: roomName, matchID: nil, context: .fromChat)))
        let result = ChatMessage.fixture(id: "s3", kind: .matchResult, text: "Marta 3–1 Noor", tournamentID: "t", matchID: "m")
        let resultNote = await opened(result)
        #expect(resultNote == .tournament(TournamentDestination(id: "t", name: roomName, matchID: "m", context: .fromChat)))
        #expect(tournaments.fetchedIDs.isEmpty)

        tournaments.details["t"] = .fixture(tournament: .fixture(id: "t", name: "Autumn Open", status: .inProgress))
        await content.load(for: started)
        let renamed = await opened(started)
        #expect(renamed == .tournament(TournamentDestination(id: "t", name: "Autumn Open", matchID: nil, context: .fromChat)))
    }

    @Test func aStartedNoteReadsTheFallbackUntilTheTournamentLoadedAndAsksOnce() async {
        tournaments.details["t"] = .fixture(tournament: .fixture(id: "t", format: .singleElimination, status: .inProgress))
        #expect(content.text(for: started) == "The tournament started")

        await content.load(for: started)
        await content.load(for: started)

        #expect(tournaments.fetchedIDs == ["t"])
        #expect(content.text(for: started) == "The bracket is out")
    }

    @Test func aGoneTournamentIsRememberedAndAskedForNoMore() async {
        await content.load(for: started)
        await content.load(for: started)

        #expect(tournaments.fetchedIDs == ["t"])
        #expect(content.linked.unavailableTournamentIDs == ["t"])
        #expect(warnings(prefixed: "Tournament t behind a system row in group g is unavailable").count == 1)
        #expect(content.text(for: started) == "The tournament started")
    }

    @Test func aTextRowOpensNothing() async {
        #expect(await opened(.fixture(id: "m1", text: "plain")) == nil)
        #expect(events.fetchedEventIDs.isEmpty && tournaments.fetchedIDs.isEmpty)
    }

    @Test func aLiveRowBumpsTheCounterOfItsKind() {
        content.recordChange(for: .eventCreated)
        #expect(eventChanges.version == 1 && tournamentChanges.version == 0)

        content.recordChange(for: .tournamentStarted)
        #expect(eventChanges.version == 1 && tournamentChanges.version == 1)

        content.recordChange(for: .text)
        #expect(eventChanges.version == 1 && tournamentChanges.version == 1)
    }

    private func opened(_ message: ChatMessage) async -> SystemRowDestination? {
        switch await content.destination(for: message, roomName: roomName) {
        case .success(let destination):
            return destination
        case .failure(let error):
            Issue.record("the row's destination failed: \(error)")
            return nil
        }
    }

    private func warnings(prefixed prefix: String) -> [String] {
        logger.messages(in: .chat, at: .warning).filter { $0.hasPrefix(prefix) }
    }
}
