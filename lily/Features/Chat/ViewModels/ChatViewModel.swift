import Foundation
import Observation

/// One open chat room. The room's messages live in the shared `ChatHistoryCache` (the realtime controller writes
/// there too, so this screen never holds a stale copy) and its unsent messages in the shared `ChatOutbox` (so a send
/// that fails after Back is still a failed bubble with Retry on the next open); this owns what is local to the screen:
/// the draft, the pictures being attached (`ChatViewModel+Attachments.swift`), the roster for live names, the read
/// marker (`ReadMarkerFlusher`), the content behind the system rows (`SystemRowContent`, reached through
/// `ChatViewModel+Events.swift`), the history paging (`ChatViewModel+History.swift`), the live subscription
/// (`ChatViewModel+Live.swift`), the clear (`ChatViewModel+Clear.swift`) and the moderation items
/// (`ChatViewModel+Moderation.swift`).
@Observable
final class ChatViewModel {
    var group: SportGroup
    var draft = MessageDraft()
    /// The pictures picked for the draft, with their uploads.
    let attachments: AttachmentComposerModel
    private(set) var members: [GroupMember] = []
    var isLoadingHistory = false
    /// The last `loadHistory()` failed for a reason that leaves the room the caller's, so the empty state offers Try
    /// again; cleared by the next load.
    var historyLoadFailed = false
    /// The older page in flight: the transcript's scroll never asks beside it, a quote tap waits for it.
    var olderPageTask: Task<Bool, Never>?
    /// Set after a 429: the composer stays closed until then.
    var cooldownUntil: Date?
    /// The caller is out of the group or the group is gone; the screen should leave.
    var isGone = false
    var liveTask: Task<Void, Never>?
    /// The epoch this screen made sure it is subscribed at; epochs only grow, so a newer one is adopted once.
    var subscribedEpoch: Int
    var hasRecordedOpen = false

    let repository: any ChatRepository
    let groups: any GroupRepository
    /// The games and tournaments behind the system rows and where a row leads (`ChatViewModel+Events.swift`).
    let systemRows: SystemRowContent
    let pasteboard: any Pasteboard
    let cache: any ChatHistoryCache
    let realtime: RealtimeSessionController
    let catchUp: ChatCatchUp
    /// The room's read marker: the dot at once, the backend at the flusher's pace (see `ReadMarkerFlusher`).
    let readMarker: ReadMarkerFlusher
    /// Whether the backend takes attachments comes from here.
    let me: MeStore
    /// The caller's block list, shared by every room; the senders whose lines `rows` hides.
    let blocks: BlockListStore
    /// The bytes of stored pictures, for the bubbles and the viewer.
    let attachmentLoader: AttachmentLoader
    let identity: any IdentityProvider
    /// Failures reach the popup through it, and a `TERMS_REQUIRED` raises the terms sheet as on the groups screens.
    let reporter: GroupErrorReporter
    /// Clears the room for the caller; shared with the Chats rows, so both do exactly the same.
    let clearer: ChatHistoryClearer
    /// The unsent and failed messages of every room; this room's are read and written as `pending`.
    let outbox: ChatOutbox
    let recorder: any InteractionRecorder
    let logger: any Logging
    let now: () -> Date
    let tryAgainDelay: Duration

    init(group: SportGroup,
         repository: any ChatRepository,
         groups: any GroupRepository,
         links: SystemRowLinks,
         pasteboard: any Pasteboard,
         cache: any ChatHistoryCache,
         realtime: RealtimeSessionController,
         catchUp: ChatCatchUp,
         unread: UnreadCenter,
         me: MeStore,
         blocks: BlockListStore,
         attachments: AttachmentComposerModel,
         attachmentLoader: AttachmentLoader,
         identity: any IdentityProvider,
         reporter: GroupErrorReporter,
         clearer: ChatHistoryClearer,
         outbox: ChatOutbox,
         recorder: any InteractionRecorder,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay) {
        self.group = group
        self.subscribedEpoch = group.channelEpoch
        self.repository = repository
        self.groups = groups
        self.systemRows = SystemRowContent(links: links, groupID: group.id, logger: logger)
        self.pasteboard = pasteboard
        self.cache = cache
        self.realtime = realtime
        self.catchUp = catchUp
        self.readMarker = ReadMarkerFlusher(groupID: group.id,
                                            repository: repository,
                                            cache: cache,
                                            unread: unread,
                                            logger: logger,
                                            now: now,
                                            sleep: sleep)
        self.me = me
        self.blocks = blocks
        self.attachments = attachments
        self.attachmentLoader = attachmentLoader
        self.identity = identity
        self.reporter = reporter
        self.clearer = clearer
        self.outbox = outbox
        self.recorder = recorder
        self.logger = logger
        self.now = now
        self.tryAgainDelay = tryAgainDelay
        readMarker.onEpoch = { [weak self] epoch in await self?.adoptEpoch(epoch) }
    }

    /// The room as the cache holds it, for reading; an empty stub while none is cached. Writes go through `mutateRoom`.
    var room: ChatRoomState {
        cache.room(for: group.id) ?? ChatRoomState(groupID: group.id, channelEpoch: group.channelEpoch)
    }

    /// This room's unsent and failed messages, as the shared outbox holds them.
    var pending: [PendingMessage] {
        get { outbox.messages(in: group.id) }
        set { outbox.replace(newValue, in: group.id) }
    }

    /// The senders whose lines `rows` hides, as the caller's block list holds them; the store is observable, so a
    /// block made in any room re-renders this transcript.
    var blockedUserIDs: Set<String> { blocks.blockedUserIDs }

    var rows: [ChatRow] {
        ChatTimeline.rows(ChatTimeline.Input(messages: room.messages,
                                             pending: pending,
                                             blockedUserIDs: blockedUserIDs,
                                             members: members,
                                             currentUserID: identity.currentUserID))
    }

    var hasOlder: Bool { room.hasOlder }
    var isCoolingDown: Bool { cooldownUntil.map { $0 > now() } ?? false }
    /// Whole seconds left on the cooldown, for the composer's caption; `nil` when the composer is open.
    var cooldownSeconds: Int? {
        cooldownUntil.map { Int($0.timeIntervalSince(now()).rounded(.up)) }.flatMap { $0 > 0 ? $0 : nil }
    }
    var canSend: Bool { outgoingDraft.isValid && !attachments.isBusy && !isCoolingDown && !isGone }

    /// Subscribe, then history (the first page, or a catch-up from the watermark), then live events and the marker.
    func appear() async {
        recordOpened()
        let subscription = RoomSubscription(groupID: group.id, epoch: room.channelEpoch)
        // Live events move the cache's epoch, never Mine's row that seeded `subscribedEpoch`; left behind, the
        // catch-up's answer would read as an epoch change and be caught up a second time.
        subscribedEpoch = max(subscribedEpoch, subscription.epoch)
        realtime.setOpenRoom(subscription)
        await realtime.ensureSubscribed(subscription)
        await loadHistory()
        // The screen may have gone (and `cancel()` run) while the page was loading; a live task now would outlive it,
        // and the open room is `cancel()`'s to clear (another screen may hold it by now).
        guard !Task.isCancelled else { return }
        // The page found the caller out of the room and `report` dropped it everywhere, the open room included: no
        // live task, marker or roster.
        guard !isGone else { return }
        startLive()
        await readMarker.opened()
        await loadMembers()
    }

    /// Leaving the screen: the live task ends, the marker is flushed, the room shrinks to what the cache keeps.
    func cancel() async {
        liveTask?.cancel()
        liveTask = nil
        realtime.setOpenRoom(nil)
        await readMarker.flush()
        cache.compact(groupID: group.id)
    }

    func sceneDidEnterBackground() async {
        await readMarker.flush()
    }

    /// The caller has seen everything on screen (a live line, an own send).
    func noteRead() {
        readMarker.noteRead()
    }

    /// Changes the room as the cache holds it and answers the result, or `nil` when the room is not cached: it was
    /// dropped while a request was in flight (the caller lost the group, or signed out), and a late answer must not
    /// bring it back. `loadNewest` caches the stub a room starts from, so nothing here ever needs to create one.
    @discardableResult
    func mutateRoom(_ change: (inout ChatRoomState) -> Void) -> ChatRoomState? {
        cache.update(groupID: group.id, change)
        return cache.room(for: group.id)
    }

    /// Cancellation stays quiet; a room the caller lost access to is dropped everywhere (Mine, cache, dot,
    /// subscription), as it is when a `member_left` names the caller; everything else reaches the popup. A refusal the
    /// room expects (`AppError.isChatRefusal`) is logged at warning, a fault at error.
    func report(_ error: any Error, during step: String) {
        guard !AppError.isCancellation(error) else { return }
        logger.log(AppError.chatLogLevel(for: error), .chat, "\(step) failed in group \(group.id): \(error)")
        if let appError = error as? AppError, appError.endsRoomAccess {
            realtime.removeGroupLocally(group.id, reason: "\(appError)")
            isGone = true
        }
        reporter.report(error)
    }

    private func loadMembers() async {
        do {
            members = try await groups.members(id: group.id)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Roster unavailable for group \(group.id): \(error)")
        }
    }

    private func recordOpened() {
        guard !hasRecordedOpen else { return }
        hasRecordedOpen = true
        recorder.record(.chatOpened(groupID: group.id, at: now()))
    }
}

extension AppError {
    /// A 500 or a lost connection after the backend may already have stored the message.
    var leavesSendOutcomeUnknown: Bool {
        self == .network || self == .messageSendFailed
    }

    /// The room is no longer the caller's to read.
    var endsRoomAccess: Bool {
        self == .notAMember || self == .groupNotFound
    }

    /// Refusals a room expects as product states, not faults, logged at warning like the event and tournament
    /// details' conflict sets so error-level lines stay faults: a cooldown, a quote whose target is gone, the terms,
    /// rejected content, a lost race the repeat lost too, a room the caller is out of, a message or a system row's
    /// game already gone.
    var isChatRefusal: Bool {
        switch self {
        case .rateLimited, .replyTargetNotFound, .termsRequired, .contentRejected, .tryAgain, .notAMember,
             .groupNotFound, .messageNotFound, .eventNotFound:
            true
        default:
            false
        }
    }

    /// The level a room logs a failure at: a refusal it expects (`isChatRefusal`) is a warning, a fault an error.
    static func chatLogLevel(for error: any Error) -> LogLevel {
        (error as? AppError)?.isChatRefusal == true ? .warning : .error
    }
}
