import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct PushCoordinatorTests {
    private let harness = PushHarness()

    private var expectedPayload: DeviceRegistrationPayload {
        DeviceRegistrationPayload(token: harness.registrar.token,
                                  platform: "ios",
                                  environment: .current,
                                  appVersion: "1.0 (42)",
                                  locale: harness.languageCode)
    }

    @Test func syncRegistersAnAuthorizedDeviceOnceAndRemembersIt() async {
        await harness.coordinator.sync()
        await harness.coordinator.sync()

        #expect(harness.devices.registrations == [expectedPayload])
        #expect(harness.coordinator.registered?.token == harness.registrar.token)
        #expect(harness.coordinator.registered?.userID == TestFixtures.user.id)
        #expect(harness.logs(.info).count == 1 && harness.logged("registered for push", at: .info) == 1)
        #expect(harness.makeCoordinator().registered == harness.coordinator.registered, "a relaunch reads the same registration")
    }

    @Test func syncDoesNothingForAGuestOrWithoutThePermission() async {
        harness.identity.currentUserID = nil
        await harness.coordinator.sync()
        harness.identity.currentUserID = TestFixtures.user.id
        harness.registrar.status = .notDetermined
        await harness.coordinator.sync()
        harness.registrar.status = .denied
        await harness.coordinator.sync()

        #expect(harness.devices.registrations.isEmpty && harness.registrar.tokenRequestCount == 0)
    }

    @Test func syncRepeatsForANewTokenAnotherUserAnotherLanguageOrAStaleRegistration() async {
        await harness.coordinator.sync()
        harness.registrar.token = String(repeating: "ef", count: 32)
        await harness.coordinator.sync()
        harness.identity.currentUserID = "someone-else"
        await harness.coordinator.sync()
        harness.languageCode = "ru"
        await harness.coordinator.sync()
        harness.clock.now = PushHarness.now.addingTimeInterval(AppConfig.Push.reregisterInterval + 1)
        await harness.coordinator.sync()

        #expect(harness.devices.registrations.count == 5)
        #expect(harness.devices.registrations.map(\.locale) == ["en", "en", "en", "ru", "ru"])
        #expect(harness.coordinator.registered?.userID == "someone-else" && harness.coordinator.registered?.locale == "ru")
    }

    @Test func offerRemindersAsksOnceAndRegistersOnAGrant() async {
        harness.registrar.status = .notDetermined

        await harness.coordinator.offerReminders()
        await harness.coordinator.offerReminders()

        #expect(harness.registrar.requestCount == 1)
        #expect(harness.devices.registrations == [expectedPayload])
        #expect(harness.logged("permission granted", at: .info) == 1)
    }

    @Test func offerRemindersRespectsARefusalAndSkipsGuests() async {
        harness.registrar.status = .notDetermined
        harness.registrar.grants = false
        await harness.coordinator.offerReminders()
        await harness.coordinator.offerReminders()
        #expect(harness.registrar.requestCount == 1 && harness.devices.registrations.isEmpty)
        #expect(harness.logs(.info).count == 1 && harness.logged("permission declined", at: .info) == 1)

        harness.registrar.status = .notDetermined
        harness.identity.currentUserID = nil
        await harness.coordinator.offerReminders()
        #expect(harness.registrar.requestCount == 1)
    }

    @Test func failuresAreLoggedNeverShown() async {
        harness.devices.registerError = .network
        await harness.coordinator.sync()
        harness.devices.registerError = nil
        harness.registrar.tokenError = .refused("no entitlement")
        await harness.coordinator.sync()

        #expect(harness.logs(.warning).count == 2)
        #expect(harness.logs(.warning).allSatisfy { $0.hasPrefix("Device registration failed: ") })
        #expect(harness.errorCenter.current == nil && harness.coordinator.registered == nil)
    }

    /// A build without the push entitlement is refused on every launch; one warning, then the system is left alone
    /// until the next launch, which asks again.
    @Test func aRefusedTokenIsNotAskedForAgainThisLaunch() async {
        harness.registrar.tokenError = .refused("no entitlement")
        await harness.coordinator.sync()
        await harness.coordinator.sync()
        #expect(harness.registrar.tokenRequestCount == 1)
        #expect(harness.logs(.warning).count == 1 && harness.logged("refused a token this launch", at: .debug) == 1)

        harness.registrar.tokenError = nil
        await harness.makeCoordinator().sync()
        #expect(harness.registrar.tokenRequestCount == 2 && harness.devices.registrations.count == 1)
    }

    @Test func aRegistrationForAUserWhoSignedOutMeanwhileIsDropped() async {
        let coordinator = harness.makeCoordinator(devices: FakeDeviceRepositoryThatSignsOut(identity: harness.identity))

        await coordinator.sync()

        #expect(coordinator.registered == nil)
    }

    @Test func signingOutUnregistersWhileTheUserIsStillKnownAndClears() async {
        await harness.coordinator.sync()

        await harness.coordinator.sessionWillEnd()
        harness.coordinator.sessionDidEnd()

        #expect(harness.devices.unregisteredTokens == [harness.registrar.token])
        #expect(harness.coordinator.registered == nil)
        #expect(harness.defaults.data(forKey: AppConfig.Push.lastRegistrationKey) == nil)
        #expect(harness.logged("unregistered for push", at: .info) == 1)
    }

    @Test func signingOutWithoutARegistrationSendsNothingAndAFailedRemovalIsAWarning() async {
        await harness.coordinator.sessionWillEnd()
        #expect(harness.devices.unregisteredTokens.isEmpty)

        await harness.coordinator.sync()
        harness.devices.unregisterError = .network
        await harness.coordinator.sessionWillEnd()

        #expect(harness.logs(.warning).count == 1 && harness.logged("unregistration failed", at: .warning) == 1)
        #expect(harness.coordinator.registered == nil)
    }

    /// A sign-out never waits on the network for long: the row expires on its own and the next registration elsewhere
    /// takes the token away.
    @Test func aSignOutGivesUpOnASlowUnregisterAndStillClears() async {
        let coordinator = harness.makeCoordinator()
        await coordinator.sync()
        harness.devices.holdsRequests = true

        let signOut = Task { await coordinator.sessionWillEnd() }
        await settle(until: { harness.sleep.held == [AppConfig.Push.unregisterTimeout] })
        harness.sleep.release()
        await signOut.value

        #expect(harness.devices.unregisteredTokens == [harness.registrar.token])
        #expect(harness.logged("timedOut", at: .warning) == 1)
        #expect(coordinator.registered == nil)
        harness.devices.releaseRequests()
    }

    @Test func aTappedReminderOpensTheGameOnTheChatsStack() async {
        harness.events.result = .success([.fixture(id: "e1")])

        harness.relay.notificationTapped(.event(id: "e1"))
        await settle(until: { !harness.navigation.chatPath.isEmpty })

        #expect(harness.events.fetchedEventIDs == ["e1"])
        #expect(harness.navigation.selectedTab == .chat && harness.coordinator.pendingTap == nil)
        #expect(harness.logged("tapped for event e1", at: .info) == 1)
    }

    /// A match reminder's tap fetches the tournament (for its name) and opens its detail with the match named.
    @Test func aTappedMatchReminderOpensTheTournamentWithTheMatchOnTheChatsStack() async {
        harness.tournaments.details["t1"] = .fixture(tournament: .fixture(id: "t1", name: "Kickers Cup"))

        harness.relay.notificationTapped(.match(tournamentID: "t1", matchID: "r01p002"))
        await settle(until: { !harness.navigation.chatPath.isEmpty })

        #expect(harness.tournaments.fetchedIDs == ["t1"] && harness.events.fetchedEventIDs.isEmpty)
        #expect(harness.navigation.selectedTab == .chat && harness.coordinator.pendingTap == nil)
        #expect(harness.logged("tapped for match r01p002 of tournament t1", at: .info) == 1)
    }

    @Test func aTapBeforeTheSessionIsRestoredWaitsForIt() async {
        harness.events.result = .success([.fixture(id: "e1")])
        harness.identity.currentUserID = nil

        harness.coordinator.handleTap(.event(id: "e1"))
        await harness.coordinator.openPendingTap()
        #expect(harness.coordinator.pendingTap == .event(id: "e1") && harness.events.fetchedEventIDs.isEmpty)

        harness.identity.currentUserID = TestFixtures.user.id
        await harness.coordinator.openPendingTap()

        #expect(harness.events.fetchedEventIDs == ["e1"] && harness.navigation.chatPath.count == 1)
        #expect(harness.coordinator.pendingTap == nil)
    }

    @Test func aTapBeforeTheCoordinatorExistsIsHandedOverOnSubscription() async {
        let relay = PushEventRelay()
        relay.notificationTapped(.event(id: "e9"))
        harness.identity.currentUserID = nil

        let coordinator = harness.makeCoordinator(relay: relay)

        #expect(coordinator.pendingTap == .event(id: "e9"))
    }
}

/// A repository whose answer arrives after the caller signed out.
@MainActor
private final class FakeDeviceRepositoryThatSignsOut: DeviceRepository {
    private let identity: FakeIdentityProvider

    init(identity: FakeIdentityProvider) {
        self.identity = identity
    }

    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration {
        identity.currentUserID = nil
        return DeviceRegistration(token: payload.token, environment: payload.environment, registeredAt: .now)
    }

    func unregister(token: String) async throws -> DeviceRemoval {
        DeviceRemoval(token: token, removed: false)
    }
}
