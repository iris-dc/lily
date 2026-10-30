import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct ShellSyncTests {
    private let realtime: RealtimeHarness
    private let push = PushHarness()
    private let session = SessionHarness()
    private let sync: ShellSync

    init() {
        let tokens = FakeAuthTokenProvider(token: JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600)))
        let realtime = RealtimeHarness(tokens: tokens)
        self.realtime = realtime
        sync = ShellSync.make(session: session.controller, navigation: push.navigation, realtime: realtime, push: push)
    }

    /// Nothing loads for a user the pool has not confirmed: a run joins the restore's check and starts after it.
    @Test func aRunWaitsForTheSessionCheck() async {
        session.auth.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { session.auth.restoreCount == 1 })

        #expect(realtime.meRepository.meCallCount == 0)
        #expect(realtime.transport.connectCount == 0)

        session.auth.releaseRequests()
        await run.value
        #expect(realtime.meRepository.meCallCount == 1)
    }

    /// A run cancelled while the check is out (the state flipped, a new key took over) loads nothing afterwards.
    @Test func aRunCancelledWhileTheSessionCheckRunsLoadsNothing() async {
        session.auth.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { session.auth.restoreCount == 1 })

        run.cancel()
        session.auth.releaseRequests()
        await run.value

        #expect(realtime.meRepository.meCallCount == 0)
        #expect(realtime.transport.connectCount == 0)
        #expect(realtime.events.requestedScopes.isEmpty)
    }

    /// The tab was picked from the cache when the root was built; the restore moves it only when the check changed the
    /// state: a pool session over an empty cache lands on Home, a dropped cached user on Explore.
    @Test func restoreMovesTheTabOnlyWhenTheCheckChangedTheState() async {
        session.auth.restoreResult = .success(TestFixtures.session)
        await sync.restore()
        #expect(push.navigation.selectedTab == .home)

        let cached = SessionHarness()
        cached.store.stored = .signedIn(TestFixtures.session)
        let controller = cached.makeController()
        cached.auth.restoreResult = .success(nil)
        let navigation = AppNavigation()
        navigation.selectedTab = .home
        await makeSync(session: controller, navigation: navigation).restore()
        #expect(navigation.selectedTab == .explore)
    }

    @Test func theConnectionWaitsForTheAccount() async {
        realtime.meRepository.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { realtime.meRepository.meCallCount == 1 })

        #expect(realtime.transport.connectCount == 0)

        realtime.meRepository.releaseRequests()
        await run.value
        #expect(realtime.transport.connectCount == 1)
    }

    @Test func mineWaitsForTheConnection() async {
        realtime.transport.holdsConnects = true
        let run = startActiveRun()
        await settle(until: { realtime.meRepository.meCallCount == 1 && realtime.transport.isConnecting })

        // Explore's Discover browse runs alongside the chain; Mine is the one that waits.
        #expect(!realtime.groups.requestedScopes.contains(.mine))

        realtime.transport.releaseConnects()
        await run.value
        #expect(realtime.groups.requestedScopes.contains(.mine))
    }

    @Test func theInboxWaitsForMine() async {
        realtime.groups.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { realtime.groups.requestedScopes.contains(.mine) })

        #expect(realtime.inboxRepository.pageRequests.isEmpty)

        realtime.groups.releaseRequests()
        await run.value
        #expect(realtime.inboxRepository.pageRequests.count == 1)
    }

    @Test func theBlockListWaitsForTheInbox() async {
        realtime.inboxRepository.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { realtime.inboxRepository.pageRequests.count == 1 })

        #expect(realtime.moderation.blocksRequestCount == 0)

        realtime.inboxRepository.releaseRequests()
        await run.value
        #expect(realtime.moderation.blocksRequestCount == 1)
    }

    @Test func pushIsOfferedAndRegisteredAfterTheBlockList() async {
        push.registrar.status = .notDetermined
        push.registrar.grants = true
        realtime.moderation.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { realtime.moderation.blocksRequestCount == 1 })

        #expect(push.registrar.requestCount == 0 && push.devices.registrations.isEmpty)

        realtime.moderation.releaseRequests()
        await run.value
        #expect(push.registrar.requestCount == 1 && push.devices.registrations.count == 1)
    }

    @Test func aGuestRunLoadsNothingUserScopedAndNeverTouchesPush() async {
        realtime.identity.currentUserID = nil
        push.identity.currentUserID = nil

        await sync.run(active: true, user: nil)

        #expect(realtime.meRepository.meCallCount == 0 && realtime.transport.connectCount == 0)
        #expect(!realtime.groups.requestedScopes.contains(.mine) && realtime.inboxRepository.pageRequests.isEmpty)
        #expect(realtime.moderation.blocksRequestCount == 0)
        #expect(push.registrar.requestCount == 0 && push.devices.registrations.isEmpty)
    }

    @Test func aBackgroundRunClosesTheConnectionAndLoadsNothing() async {
        await sync.run(active: true, user: TestFixtures.user)
        let afterTheActiveRun = requestCounts

        await sync.run(active: false, user: TestFixtures.user)

        #expect(realtime.transport.disconnectCount == 1 && !realtime.controller.isActive)
        #expect(requestCounts == afterTheActiveRun)
    }

    @Test func aRunCancelledWhileTheAccountLoadsNeverSetsTheConnectionDesired() async {
        realtime.meRepository.holdsRequests = true
        let run = startActiveRun()
        await settle(until: { realtime.meRepository.meCallCount == 1 })

        run.cancel()
        realtime.meRepository.releaseRequests()
        await run.value

        #expect(realtime.transport.connectCount == 0 && !realtime.controller.isActive)
    }

    @Test func restoreLandsOnTheStartTabBeforeOpeningThePendingTap() async {
        session.auth.restoreResult = .success(TestFixtures.session)
        push.events.result = .success([.fixture(id: "e1")])
        push.identity.currentUserID = nil
        push.coordinator.handleTap(.event(id: "e1"))
        push.identity.currentUserID = TestFixtures.user.id

        await sync.restore()

        #expect(push.navigation.selectedTab == .chat && push.navigation.chatPath.count == 1)
        #expect(push.coordinator.pendingTap == nil)
    }

    @Test func restoreWithoutASessionKeepsTheTapPending() async {
        session.auth.restoreResult = .success(nil)
        push.identity.currentUserID = nil
        push.coordinator.handleTap(.event(id: "e1"))

        await sync.restore()

        #expect(push.navigation.selectedTab == .explore && push.navigation.chatPath.isEmpty)
        #expect(push.coordinator.pendingTap == .event(id: "e1"))
    }

    private func makeSync(session: SessionController, navigation: AppNavigation) -> ShellSync {
        ShellSync.make(session: session, navigation: navigation, realtime: realtime, push: push)
    }

    private func startActiveRun() -> Task<Void, Never> {
        let sync = sync
        return Task { await sync.run(active: true, user: TestFixtures.user) }
    }

    /// Every request a run can make, so a run can be shown to have made none.
    private var requestCounts: RequestCounts {
        RequestCounts(account: realtime.meRepository.meCallCount,
                      groups: realtime.groups.requestedScopes.count,
                      inboxPages: realtime.inboxRepository.pageRequests.count,
                      blockLists: realtime.moderation.blocksRequestCount,
                      permissionAsks: push.registrar.requestCount,
                      registrations: push.devices.registrations.count,
                      events: realtime.events.requestedScopes.count,
                      tournaments: realtime.tournaments.requestedScopes.count)
    }

    private struct RequestCounts: Equatable {
        let account: Int
        let groups: Int
        let inboxPages: Int
        let blockLists: Int
        let permissionAsks: Int
        let registrations: Int
        let events: Int
        let tournaments: Int
    }
}
