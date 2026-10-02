import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct EventOpenerTests {
    private let events = FakeEventRepository()
    private let navigation = AppNavigation()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let opener: EventOpener

    init() {
        errorCenter = ErrorCenter(logger: logger)
        opener = EventOpener(events: events,
                             navigation: navigation,
                             reporter: GroupErrorReporter(errorCenter: errorCenter) {},
                             logger: logger)
    }

    @Test func aKnownGameIsFetchedAndPushedOnTheChatsStack() async {
        events.result = .success([.fixture(id: "e1")])

        let opened = await opener.open(eventID: "e1", from: "a test")

        #expect(opened && events.fetchedEventIDs == ["e1"])
        #expect(navigation.selectedTab == .chat && navigation.chatPath.count == 1)
    }

    @Test func aGoneGameReachesThePopupWithOneWarning() async {
        events.result = .success([])

        let opened = await opener.open(eventID: "e1", from: "a notification")

        #expect(!opened && navigation.chatPath.isEmpty)
        #expect(errorCenter.current?.error == .eventNotFound)
        #expect(logger.messages(in: .events, at: .warning) == ["Event e1 behind a notification is unavailable: eventNotFound"])
    }
}
