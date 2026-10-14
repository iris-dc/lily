import Foundation
import Testing
@testable import lily

/// `PushCoordinator` cases that `PushCoordinatorTests`, at SwiftLint's type-body limit, has no room for.
@MainActor
struct PushCoordinatorSignOutTests {
    private let harness = PushHarness()

    /// The PUT in flight would otherwise leave this device registered to an account that is gone.
    @Test func aSignOutWaitsForTheRegistrationInFlight() async {
        harness.devices.holdsRequests = true
        let sync = Task { await harness.coordinator.sync() }
        await settle(until: { harness.devices.registrations.count == 1 })

        let signOut = Task { await harness.coordinator.sessionWillEnd() }
        await settle(until: { harness.sleep.held == [AppConfig.Push.unregisterTimeout] })
        harness.devices.releaseRequests()
        await sync.value
        await signOut.value

        #expect(harness.devices.unregisteredTokens == [harness.registrar.token])
        #expect(harness.coordinator.registered == nil)
        #expect(harness.logged("unregistered for push", at: .info) == 1)
        #expect(harness.defaults.data(forKey: AppConfig.Push.lastRegistrationKey) == nil)
    }

    @Test func aSignOutDuringARotatingRegistrationRemovesBothTokens() async {
        let first = harness.registrar.token
        await harness.coordinator.sync()
        harness.clock.now = PushHarness.now.addingTimeInterval(AppConfig.Push.reregisterInterval + 1)
        let rotated = String(repeating: "ef", count: 32)
        harness.registrar.token = rotated
        harness.devices.holdsRequests = true
        let sync = Task { await harness.coordinator.sync() }
        await settle(until: { harness.devices.registrations.count == 2 })

        let signOut = Task { await harness.coordinator.sessionWillEnd() }
        await settle(until: { harness.sleep.held == [AppConfig.Push.unregisterTimeout] })
        harness.devices.releaseRequests()
        await sync.value
        await signOut.value

        #expect(Set(harness.devices.unregisteredTokens) == [first, rotated])
        #expect(harness.devices.unregisteredTokens.count == 2)
        #expect(harness.coordinator.registered == nil)
    }

    @Test func concurrentSyncsRegisterOnce() async {
        harness.devices.holdsRequests = true
        let coordinator = harness.coordinator

        async let first: Void = coordinator.sync()
        async let second: Void = coordinator.sync()
        await settle(until: { harness.devices.registrations.count == 1 })
        harness.devices.releaseRequests()
        _ = await (first, second)

        #expect(harness.devices.registrations.count == 1)
        #expect(harness.registrar.tokenRequestCount == 1)
        #expect(coordinator.registered?.token == harness.registrar.token)
    }

    /// A tap kept for a session that never came back is not opened for the next account.
    @Test func aTapKeptWhileSignedOutIsDroppedByALaterSignOut() async {
        harness.identity.currentUserID = nil
        harness.coordinator.handleTap(.event(id: "e1"))
        harness.identity.currentUserID = "B"

        harness.coordinator.sessionDidEnd()
        harness.identity.currentUserID = "C"
        await harness.coordinator.openPendingTap()

        #expect(harness.events.fetchedEventIDs.isEmpty)
        #expect(harness.coordinator.pendingTap == nil)
    }
}
