import Foundation
import Testing
@testable import lily

@MainActor
struct PushEventRelayTests {
    private let sleep: HeldSleep
    private let relay: PushEventRelay

    init() {
        let sleep = HeldSleep()
        self.sleep = sleep
        relay = PushEventRelay { try await sleep.sleep(for: $0) }
    }

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
        let waiting = Task { try await relay.token(timeout: .seconds(10)) {} }
        await settle(until: { sleep.held.count == 1 })

        sleep.release()

        await #expect(throws: PushRegistrationError.timedOut) { try await waiting.value }
    }

    /// A timeout firing after the system answered finds no waiter and must leave the next registration's alone: a second
    /// resume of the answered continuation would crash the app.
    @Test func aLateTimeoutAfterDeliveryIsHarmless() async throws {
        let answered = Task { try await relay.token(timeout: .seconds(10)) {} }
        await settle(until: { sleep.held.count == 1 })
        relay.deliver(token: Data([0x01, 0xab, 0xff]))
        #expect(try await answered.value == "01abff")
        let later = Task { try await relay.token(timeout: .seconds(20)) {} }
        await settle(until: { sleep.held.count == 2 })

        sleep.release()

        await #expect(throws: PushRegistrationError.timedOut) { try await later.value }
        #expect(!relay.isWaiting)
        #expect(sleep.held.isEmpty)
    }

    @Test func aTapWaitsForTheHandlerAndLaterOnesGoStraightThrough() {
        var opened: [PushTap] = []
        relay.notificationTapped(.event(id: "e1"))

        relay.tapHandler = { opened.append($0) }
        relay.notificationTapped(.match(tournamentID: "t1", matchID: "r01p001"))

        #expect(opened == [.event(id: "e1"), .match(tournamentID: "t1", matchID: "r01p001")])
    }
}
