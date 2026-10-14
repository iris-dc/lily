import Foundation
@testable import lily

/// Every collaborator of the realtime controller and the chat view model, over fakes: one transport, one cache, one
/// store, a held sleep and a hand-moved clock. Jitter is pinned to the top of its range (`random` answers the upper
/// bound), so every backoff a test waits for is exact.
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
    let outbox = ChatOutbox()
    let meRepository = FakeMeRepository()
    let moderation = FakeModerationRepository()
    let uploader = FakeAttachmentUploader()
    let preparer = FakeMediaPreparer()
    let attachmentCache = FakeAttachmentCache()
    let errorCenter: ErrorCenter
    let store: MyGroupsStore
    let inbox: InboxStore
    let me: MeStore
    let blocks: BlockListStore
    let cache: InMemoryChatHistoryCache
    let catchUp: ChatCatchUp
    let clearer: ChatHistoryClearer
    let attachmentLoader: AttachmentLoader
    let controller: RealtimeSessionController
    private let terms: TermsCountingReporter

    var reporter: GroupErrorReporter { terms.reporter }
    /// How often the reporter asked for the terms sheet.
    var termsRequiredCount: Int { terms.termsRequiredCount }

    init(tokens: FakeAuthTokenProvider? = nil) {
        self.tokens = tokens
        errorCenter = ErrorCenter(logger: logger)
        terms = TermsCountingReporter(errorCenter: errorCenter)
        store = MyGroupsStore(repository: groups, identity: identity, changes: changes, errorCenter: errorCenter, logger: logger)
        inbox = InboxStore(repository: inboxRepository, identity: identity, errorCenter: errorCenter, logger: logger)
        me = MeStore(repository: meRepository, identity: identity, errorCenter: errorCenter, logger: logger)
        blocks = BlockListStore(repository: moderation, identity: identity, logger: logger)
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: chat, cache: cache, logger: logger)
        attachmentLoader = AttachmentLoader(repository: chat, cache: attachmentCache, logger: logger)
        let sleep = self.sleep
        let clock = self.clock
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
                                               tournamentChanges: tournamentChanges,
                                               groupRepository: groups,
                                               errorCenter: errorCenter,
                                               logger: logger,
                                               now: { clock.now },
                                               sleep: { try await sleep.sleep(for: $0) },
                                               random: { $0.upperBound })
        clearer = ChatHistoryClearer(repository: chat,
                                     cache: cache,
                                     outbox: outbox,
                                     realtime: controller,
                                     unread: unread,
                                     reporter: terms.reporter,
                                     logger: logger)
    }

    /// The app is active with the test user signed in.
    func connect() async {
        await controller.setDesired(active: true, user: TestFixtures.user)
    }

    /// Mine as `count` member groups g1...gN.
    static func mine(_ count: Int) -> [SportGroup] {
        (1...count).map { .fixture(id: "g\($0)", role: .member) }
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
                      blocks: blocks,
                      attachments: makeAttachmentComposer(for: group),
                      attachmentLoader: attachmentLoader,
                      identity: identity,
                      reporter: reporter,
                      clearer: clearer,
                      outbox: outbox,
                      recorder: recorder,
                      logger: logger,
                      now: { [clock] in clock.now },
                      sleep: { [sleep] in try await sleep.sleep(for: $0) },
                      tryAgainDelay: .zero)
    }

    func makeAttachmentComposer(for group: SportGroup,
                                maxPerMessage: Int = AppConfig.Chat.Attachments.maxPerMessage) -> AttachmentComposerModel {
        AttachmentComposerModel(groupID: group.id,
                                caps: .caps(for: group),
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

    /// Reads what the controller hands the room's consumers from now on.
    func sink(for groupID: String) -> EnvelopeSink {
        EnvelopeSink(groupID: groupID, controller: controller)
    }
}

/// What the room's consumers were handed, in order: a test that posts a foreign envelope before a valid one knows,
/// once the valid one is here, that the foreign one was judged.
@MainActor
final class EnvelopeSink {
    private(set) var received: [RealtimeEnvelope] = []
    private var reader: Task<Void, Never>?

    var messageIDs: [String] {
        received.compactMap { envelope in
            if case .message(let message) = envelope { message.id } else { nil }
        }
    }

    init(groupID: String, controller: RealtimeSessionController) {
        let stream = controller.envelopes(for: groupID)
        reader = Task { @MainActor [weak self] in
            for await envelope in stream { self?.received.append(envelope) }
        }
    }

    deinit {
        reader?.cancel()
    }
}
