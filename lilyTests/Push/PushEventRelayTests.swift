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
        var opened: [String] = []
        relay.notificationTapped(eventID: "e1")

        relay.tapHandler = { opened.append($0) }
        relay.notificationTapped(eventID: "e2")

        #expect(opened == ["e1", "e2"])
    }
}
