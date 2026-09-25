import Foundation
@testable import lily

@MainActor
final class JitterSource {
    var pick: (ClosedRange<Double>) -> Double = { $0.upperBound }
}

/// Every collaborator of the realtime controller and the chat view model, over fakes: one transport, one cache, one
/// store, a held sleep and a hand-moved clock. Jitter is pinned to the top of its range unless a test says otherwise.
@MainActor
final class RealtimeHarness {
    let transport = FakeRealtimeTransport()
    let endpoint = FakeRealtimeEndpointProvider()
    let tokens: FakeAuthTokenProvider?
    let chat = FakeChatRepository()
    let groups = FakeGroupRepository()
    let events = FakeEventRepository()
    let eventChanges = ChangeTracker()
    let pasteboard = SpyPasteboard()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let changes = ChangeTracker()
    let logger = SpyLogger()
    let sleep = HeldSleep()
    let clock = DateClock()
    let recorder = SpyInteractionRecorder()
    let unread = UnreadCenter()
    let errorCenter: ErrorCenter
    let store: MyGroupsStore
    let cache: InMemoryChatHistoryCache
    let catchUp: ChatCatchUp
    let controller: RealtimeSessionController
    /// What the controller's jitter draws; a test replaces `pick` to steer it.
    let jitter = JitterSource()

    init(tokens: FakeAuthTokenProvider? = nil) {
        self.tokens = tokens
        errorCenter = ErrorCenter(logger: logger)
        store = MyGroupsStore(repository: groups, identity: identity, changes: changes, errorCenter: errorCenter, logger: logger)
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: chat, cache: cache, logger: logger)
        let sleep = self.sleep
        let clock = self.clock
        let jitter = self.jitter
        controller = RealtimeSessionController(transport: transport,
                                               endpointProvider: endpoint,
                                               tokenProvider: tokens,
                                               identity: identity,
                                               store: store,
                                               cache: cache,
                                               catchUp: catchUp,
                                               unread: unread,
                                               groupChanges: changes,
                                               groupRepository: groups,
                                               errorCenter: errorCenter,
                                               logger: logger,
                                               now: { clock.now },
                                               sleep: { try await sleep.sleep(for: $0) },
                                               random: { jitter.pick($0) })
    }

    /// The app is active with the test user signed in.
    func connect() async {
        await controller.setDesired(active: true, user: TestFixtures.user)
    }

    func chatLogs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .chat, at: level)
    }

    func makeChatViewModel(for group: SportGroup) -> ChatViewModel {
        ChatViewModel(group: group,
                      repository: chat,
                      groups: groups,
                      events: events,
                      eventChanges: eventChanges,
                      pasteboard: pasteboard,
                      cache: cache,
                      realtime: controller,
                      catchUp: catchUp,
                      unread: unread,
                      identity: identity,
                      errorCenter: errorCenter,
                      recorder: recorder,
                      logger: logger,
                      now: { [clock] in clock.now },
                      sleep: { [sleep] in try await sleep.sleep(for: $0) })
    }

    /// Gives fire-and-forget work every chance to run, so "nothing more happened" can be asserted.
    func yield() async {
        for _ in 0..<20 { await Task.yield() }
    }
}
