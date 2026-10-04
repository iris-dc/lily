import Foundation
import Testing
@testable import lily

@MainActor
struct PushEventRelayTests {
    private let relay = PushEventRelay()

    @Test func theDeliveredTokenReachesTheWaiterAsHex() async throws {
        let waiting = Task { try await relay.token(timeout: .seconds(5)) {} }
        await settle(until: { relay.isWaiting })

        relay.deliver(token: Data([0x01, 0xab, 0xff]))

        #expect(try await waiting.value == "01abff")
    }

    @Test func aRefusalReachesTheWaiterAsAnError() async {
        let waiting = Task { try await relay.token(timeout: .seconds(5)) {} }
        await settle(until: { relay.isWaiting })

        relay.fail(URLError(.notConnectedToInternet))

        await #expect(throws: PushRegistrationError.self) { try await waiting.value }
    }

    @Test func aSilentSystemTimesOut() async {
        await #expect(throws: PushRegistrationError.timedOut) {
            try await relay.token(timeout: .milliseconds(10)) {}
        }
    }

    @Test func aTapWaitsForTheHandlerAndLaterOnesGoStraightThrough() {
        var opened: [PushTap] = []
        relay.notificationTapped(.event(id: "e1"))

        relay.tapHandler = { opened.append($0) }
        relay.notificationTapped(.match(tournamentID: "t1", matchID: "r01p001"))

        #expect(opened == [.event(id: "e1"), .match(tournamentID: "t1", matchID: "r01p001")])
    }
}
