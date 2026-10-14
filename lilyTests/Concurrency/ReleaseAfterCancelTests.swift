import Testing
@testable import lily

/// The long-lived types let go once their screen or session is over: every timer, debounce, reconnect and subscription
/// task captures `[weak self]` (or no self at all), so a cancelled one keeps nothing alive. A failure here is a retain
/// path: a strong capture in app code, or a harness-owned collaborator holding the type.
@MainActor
struct ReleaseAfterCancelTests {
    /// The live task ends with the consumer it registered; the harness stays, only the view model goes.
    @Test func chatViewModelIsReleasedAfterCancel() async {
        let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        await harness.connect()
        weak var released: ChatViewModel?

        do {
            let viewModel = harness.makeChatViewModel(for: group)
            released = viewModel
            await viewModel.appear()
            await settle(until: { harness.controller.consumers.count == 1 })
            await viewModel.cancel()
            await settle(until: { harness.controller.consumers.isEmpty })
        }

        #expect(released == nil, "the room's view model outlived its cancel")
    }

    /// Sign-out closes the connection in a task of its own; once that task has run, the renewal, reconnect,
    /// subscription and resubscribe tasks hold the controller weakly or not at all. The whole harness is built inside
    /// the block and dropped with the controller, because the harness object holds it through `clearer`
    /// (`ChatHistoryClearer.realtime` is a strong `let`).
    @Test func realtimeSessionControllerIsReleasedAfterSessionDidEnd() async {
        weak var released: RealtimeSessionController?

        do {
            let harness = RealtimeHarness()
            harness.groups.result = .success([.fixture(id: "g1", role: .member)])
            await harness.connect()
            released = harness.controller
            harness.controller.sessionDidEnd()
            await settle(until: { harness.transport.disconnectCount == 1 && harness.controller.state == .disconnected })
            for _ in 0..<10 { await Task.yield() }
        }

        #expect(released == nil, "the controller outlived its sign-out")
    }

    /// The debounce task captures `[weak self, sleep]`, so a cancelled sleep wakes nothing and holds nothing.
    @Test func discoverGroupsViewModelIsReleasedAfterCancel() async {
        let harness = GroupHarness()
        let sleep = HeldSleep()
        weak var released: DiscoverGroupsViewModel?

        do {
            let viewModel = DiscoverGroupsViewModel(changes: harness.changes,
                                                    repository: harness.repository,
                                                    identity: harness.identity,
                                                    locationService: harness.location,
                                                    errorCenter: harness.errorCenter,
                                                    recorder: harness.recorder,
                                                    logger: harness.logger,
                                                    sleep: { [sleep] in try await sleep.sleep(for: $0) })
            released = viewModel
            viewModel.query = "x"
            await settle(until: { sleep.requested.count == 1 })
            viewModel.cancel()
            await settle(until: { sleep.held.isEmpty })
        }

        #expect(released == nil, "the Discover view model outlived its cancel")
    }

    /// `syncProfile` captures `[profileRepository, logger]`, never the controller; the sign-out cancels the sync, whose
    /// sleep ends the task before the harness goes.
    @Test func sessionControllerIsReleasedAfterSignOutCancelsTheProfileSync() async {
        weak var released: SessionController?

        do {
            let harness = SessionHarness()
            harness.profile.delay = .seconds(60)
            released = harness.controller
            _ = await harness.controller.signIn(with: .apple)
            await harness.controller.signOut()
            await harness.controller.profileSync?.value
        }

        #expect(released == nil, "the session controller outlived its sign-out")
    }
}
