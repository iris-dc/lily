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
    let inboxRepository = FakeInboxRepository()
    let events = FakeEventRepository()
    let eventChanges = ChangeTracker()
    let tournaments = FakeTournamentRepository()
    let tournamentChanges = ChangeTracker()
    let pasteboard = SpyPasteboard()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let changes = ChangeTracker()
    let logger = SpyLogger()
    let sleep = HeldSleep()
    let clock = DateClock()
    let recorder = SpyInteractionRecorder()
    let unread = UnreadCenter()
    let meRepository = FakeMeRepository()
    let uploader = FakeAttachmentUploader()
    let preparer = FakeMediaPreparer()
    let attachmentCache = FakeAttachmentCache()
    let errorCenter: ErrorCenter
    let reporter: GroupErrorReporter
    let store: MyGroupsStore
    let inbox: InboxStore
    let me: MeStore
    let cache: InMemoryChatHistoryCache
    let catchUp: ChatCatchUp
    let clearer: ChatHistoryClearer
    let attachmentLoader: AttachmentLoader
    let controller: RealtimeSessionController
    /// What the controller's jitter draws; a test replaces `pick` to steer it.
    let jitter = JitterSource()
    private let termsRequests = CallCounter()

    /// How often the reporter asked for the terms sheet.
    var termsRequiredCount: Int { termsRequests.count }

    init(tokens: FakeAuthTokenProvider? = nil) {
        self.tokens = tokens
        errorCenter = ErrorCenter(logger: logger)
        let termsRequests = self.termsRequests
        reporter = GroupErrorReporter(errorCenter: errorCenter) { termsRequests.increment() }
        store = MyGroupsStore(repository: groups, identity: identity, changes: changes, errorCenter: errorCenter, logger: logger)
        inbox = InboxStore(repository: inboxRepository, identity: identity, errorCenter: errorCenter, logger: logger)
        me = MeStore(repository: meRepository, identity: identity, errorCenter: errorCenter, logger: logger)
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: chat, cache: cache, logger: logger)
        attachmentLoader = AttachmentLoader(repository: chat, cache: attachmentCache, logger: logger)
        clearer = ChatHistoryClearer(repository: chat,
                                     cache: cache,
                                     myGroups: store,
                                     unread: unread,
                                     reporter: reporter,
                                     logger: logger)
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
                                               inbox: inbox,
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
                      links: SystemRowLinks(events: events,
                                            tournaments: tournaments,
                                            eventChanges: eventChanges,
                                            tournamentChanges: tournamentChanges),
                      pasteboard: pasteboard,
                      cache: cache,
                      realtime: controller,
                      catchUp: catchUp,
                      unread: unread,
                      me: me,
                      attachments: makeAttachmentComposer(for: group),
                      attachmentLoader: attachmentLoader,
                      identity: identity,
                      reporter: reporter,
                      clearer: clearer,
                      recorder: recorder,
                      logger: logger,
                      now: { [clock] in clock.now },
                      sleep: { [sleep] in try await sleep.sleep(for: $0) },
                      tryAgainDelay: .zero)
    }

    func makeAttachmentComposer(for group: SportGroup,
                                maxPerMessage: Int = AppConfig.Chat.Attachments.maxPerMessage) -> AttachmentComposerModel {
        AttachmentComposerModel(groupID: group.id,
                                repository: chat,
                                uploader: uploader,
                                preparer: preparer,
                                cache: attachmentCache,
                                reporter: reporter,
                                logger: logger,
                                maxPerMessage: maxPerMessage)
    }

    /// Gives fire-and-forget work every chance to run, so "nothing more happened" can be asserted.
    func yield() async {
        for _ in 0..<20 { await Task.yield() }
    }
}
