import Foundation
import Testing
@testable import lily

/// A foreground with no connection to recover through: the open room is still caught up over REST.
@MainActor
struct RealtimeOfflineResumeTests {
    /// No endpoint means no resume protocol; the open chat still has to show what arrived while the app was away.
    @Test func aResumeWithoutAConnectionCatchesUpTheOpenRoom() async {
        let harness = RealtimeHarness()
        harness.endpoint.url = nil
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 1))
        harness.chat.newerPages = [.fixture([.fixture(id: "m2", groupID: "g1")], epoch: 2)]

        await harness.connect()

        #expect(harness.controller.state == .unavailable && harness.transport.connectCount == 0)
        #expect(harness.chat.newerRequests.map { "\($0.groupID)/\($0.after)" } == ["g1/m1"])
        #expect(harness.cache.room(for: "g1")?.messages.map(\.id) == ["m1", "m2"])
        #expect(harness.controller.knownEpochs["g1"] == 2, "the epoch the page answered is kept for the next connect")
        #expect(harness.chatLogs(.info).contains("No connection; catching up the open room g1 over REST"))

        await harness.controller.suspend()
        await harness.controller.resume()
        #expect(harness.chat.newerRequests.count == 2, "every return from the background catches the open room up")

        await harness.connect()
        #expect(harness.chat.newerRequests.count == 2, "an active <-> inactive flip suspended nothing; nothing to catch up")

        harness.controller.setOpenRoom(nil)
        await harness.controller.suspend()
        await harness.controller.resume()
        #expect(harness.chat.newerRequests.count == 2, "no open room, nothing to catch up")
    }

    /// A connection that did come up leaves the catch-up to the resume protocol; nothing runs twice.
    @Test func aResumeWithAConnectionLeavesTheCatchUpToTheResumeProtocol() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 1))

        await harness.connect()

        #expect(harness.controller.state == .connected)
        #expect(harness.chat.newerRequests.count == 1, "the resume protocol's catch-up of the open room, once")
        #expect(!harness.chatLogs(.info).contains { $0.hasPrefix("No connection") })
    }
}
