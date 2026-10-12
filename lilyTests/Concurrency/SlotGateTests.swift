import Testing
@testable import lily

/// The concurrency cap behind the uploads: at most the limit hold a slot and the rest wait in order, a released slot
/// is handed to the next waiter or freed, and a waiter cancelled while parked leaves the queue without one.
@MainActor
struct SlotGateTests {
    @Test func atMostTheLimitRunAtOnceAndTheRestFollowInOrder() async throws {
        let gate = SlotGate(limit: 2)
        let order = AcquisitionOrder()
        let holders = (1...4).map { number in Task { try await gate.acquire(); order.record(number) } }
        await settle(until: { gate.waiting == 2 })
        #expect(gate.active == 2 && order.entries == [1, 2])

        gate.release()
        await settle(until: { order.entries.count == 3 })
        #expect(order.entries == [1, 2, 3] && gate.active == 2 && gate.waiting == 1, "the slot was handed on, not freed")

        gate.release()
        await settle(until: { order.entries.count == 4 })
        #expect(order.entries == [1, 2, 3, 4] && gate.waiting == 0)

        gate.release()
        gate.release()
        #expect(gate.active == 0)
        for holder in holders { try await holder.value }
    }

    @Test func aReleaseWithNobodyWaitingFreesTheSlot() async throws {
        let gate = SlotGate(limit: 1)
        try await gate.acquire()
        #expect(gate.active == 1)

        gate.release()

        #expect(gate.active == 0 && gate.waiting == 0)
        try await gate.acquire()
        #expect(gate.active == 1, "the freed slot is taken again at once")
        gate.release()
    }

    @Test func aCancelledWaiterLeavesTheQueueWithoutASlot() async throws {
        let gate = SlotGate(limit: 1)
        try await gate.acquire()
        let waiter = Task { try await gate.acquire() }
        await settle(until: { gate.waiting == 1 })

        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(gate.waiting == 0 && gate.active == 1)
        gate.release()
        #expect(gate.active == 0, "the holder's release met no waiter")
    }

    @Test func anAlreadyCancelledCallerGetsNoSlot() async {
        let gate = SlotGate(limit: 1)
        let caller = Task { try await gate.acquire() }

        caller.cancel()

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(gate.active == 0 && gate.waiting == 0)
    }
}

/// Who got a slot, in order.
@MainActor
private final class AcquisitionOrder {
    private(set) var entries: [Int] = []

    func record(_ number: Int) {
        entries.append(number)
    }
}
