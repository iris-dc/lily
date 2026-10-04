import Foundation
import Observation

/// One open chat room. The room's messages live in the shared `ChatHistoryCache` (the realtime controller writes
/// there too, so this screen never holds a stale copy); this owns what is local to the screen: the draft, the unsent
/// messages, the pictures being attached (`ChatViewModel+Attachments.swift`), the roster for live names, the read
/// marker, the history paging (`ChatViewModel+History.swift`), the live subscription (`ChatViewModel+Live.swift`) and
/// the clear (`ChatViewModel+Clear.swift`).
@Observable
final class ChatViewModel {
    var group: SportGroup
    var draft = MessageDraft()
    var pending: [PendingMessage] = []
    /// The pictures picked for the draft, with their uploads.
    let attachments: AttachmentComposerModel
    private(set) var members: [GroupMember] = []
    var isLoadingHistory = false
    var isLoadingOlder = false
    /// Set after a 429: the composer stays closed until then.
    var cooldownUntil: Date?
    /// The caller is out of the group or the group is gone; the screen should leave.
    var isGone = false
    /// Senders whose messages are hidden; the block list feeds it.
    var blockedUserIDs: Set<String> = []
    var liveTask: Task<Void, Never>?
    var readMarkerTask: Task<Void, Never>?
    var lastFlushedReadID: String?
    var lastFlushAt: Date?
    /// The epoch this screen made sure it is subscribed at; epochs only grow, so a newer one is adopted once.
    var subscribedEpoch: Int
    var hasRecordedOpen = false
    /// The games and tournaments behind the system rows on screen, fetched once each (`ChatViewModel+Events.swift`).
    var linked = LinkedContent()

    let repository: any ChatRepository
    let groups: any GroupRepository
    /// What the system rows point at, and the change counters a live one bumps.
    let links: SystemRowLinks
    let pasteboard: any Pasteboard
    let cache: any ChatHistoryCache
    let realtime: RealtimeSessionController
    let catchUp: ChatCatchUp
    let unread: UnreadCenter
    /// Whether the backend takes attachments comes from here.
    let me: MeStore
    /// The bytes of stored pictures, for the bubbles and the viewer.
    let attachmentLoader: AttachmentLoader
    let identity: any IdentityProvider
    /// Failures reach the popup through it, and a `TERMS_REQUIRED` raises the terms sheet as on the groups screens.
    let reporter: GroupErrorReporter
    /// Clears the room for the caller; shared with the Chats rows, so both do exactly the same.
    let clearer: ChatHistoryClearer
    let recorder: any InteractionRecorder
    let logger: any Logging
    let now: () -> Date
    let sleep: Sleep
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
         attachments: AttachmentComposerModel,
         attachmentLoader: AttachmentLoader,
         identity: any IdentityProvider,
         reporter: GroupErrorReporter,
         clearer: ChatHistoryClearer,
         recorder: any InteractionRecorder,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay) {
        self.group = group
        self.subscribedEpoch = group.channelEpoch
        self.repository = repository
        self.groups = groups
        self.links = links
        self.pasteboard = pasteboard
        self.cache = cache
        self.realtime = realtime
        self.catchUp = catchUp
        self.unread = unread
        self.me = me
        self.attachments = attachments
        self.attachmentLoader = attachmentLoader
        self.identity = identity
        self.reporter = reporter
        self.clearer = clearer
        self.recorder = recorder
        self.logger = logger
        self.now = now
        self.sleep = sleep
        self.tryAgainDelay = tryAgainDelay
    }

    /// The room as the cache holds it, for reading; an empty stub while none is cached. Writes go through `mutateRoom`.
    var room: ChatRoomState {
        cache.room(for: group.id) ?? ChatRoomState(groupID: group.id, channelEpoch: group.channelEpoch)
    }

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
        realtime.setOpenRoom(subscription)
        await realtime.ensureSubscribed(subscription)
        await loadHistory()
        // The screen may have gone (and `cancel()` run) while the page was loading; a live task now would outlive it.
        guard !Task.isCancelled else { return }
        startLive()
        unread.markRead(groupID: group.id, upTo: room.displayMaxID)
        await flushReadMarker()
        await loadMembers()
    }

    /// Leaving the screen: the live task ends, the marker is flushed, the room shrinks to what the cache keeps.
    func cancel() async {
        liveTask?.cancel()
        liveTask = nil
        realtime.setOpenRoom(nil)
        await flushReadMarker()
        cache.compact(groupID: group.id)
    }

    func sceneDidEnterBackground() async {
        await flushReadMarker()
    }

    /// The caller has seen everything on screen: the dot goes at once, the backend hears at most once per
    /// `AppConfig.Chat.readMarkFlushInterval` while the room is open, and on leaving or backgrounding.
    func noteRead() {
        unread.markRead(groupID: group.id, upTo: room.displayMaxID)
        guard readMarkerTask == nil, room.displayMaxID != lastFlushedReadID else { return }
        let elapsed = lastFlushAt.map { now().timeIntervalSince($0) } ?? .infinity
        let wait = max(AppConfig.Chat.readMarkFlushInterval - elapsed, 0)
        // The task lets go of its slot first, or the flush would cancel the very task running it before the request.
        readMarkerTask = Task { [weak self, sleep] in
            if wait > 0 { guard (try? await sleep(.seconds(wait))) != nil else { return } }
            guard let self else { return }
            readMarkerTask = nil
            await flushReadMarker()
        }
    }

    func flushReadMarker() async {
        readMarkerTask?.cancel()
        readMarkerTask = nil
        guard let id = room.displayMaxID, id != lastFlushedReadID else { return }
        let previous = lastFlushedReadID
        lastFlushedReadID = id
        lastFlushAt = now()
        do {
            let marker = try await repository.markRead(groupID: group.id, messageID: id)
            logger.debug(.chat, "Read marker flushed for group \(group.id)")
            await adoptEpoch(marker.channelEpoch)
        } catch {
            lastFlushedReadID = previous
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Read marker failed for group \(group.id): \(error)")
        }
    }

    /// Changes the room as the cache holds it and answers the result, or `nil` when the room is not cached: it was
    /// dropped while a request was in flight (the caller lost the group, or signed out), and a late answer must not
    /// bring it back. `loadNewest` caches the stub a room starts from, so nothing here ever needs to create one.
    @discardableResult
    func mutateRoom(_ change: (inout ChatRoomState) -> Void) -> ChatRoomState? {
        cache.update(groupID: group.id, change)
        return cache.room(for: group.id)
    }

    /// Cancellation stays quiet; a room the caller lost access to is dropped; everything else reaches the popup.
    func report(_ error: any Error, during step: String) {
        guard !AppError.isCancellation(error) else { return }
        logger.error(.chat, "\(step) failed in group \(group.id): \(error)")
        if let appError = error as? AppError, appError.endsRoomAccess {
            cache.drop(groupID: group.id, reason: "\(appError)")
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
}
