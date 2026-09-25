import Foundation
import Observation

/// One open chat room. The room's messages live in the shared `ChatHistoryCache` (the realtime controller writes
/// there too, so this screen never holds a stale copy); this owns what is local to the screen: the draft, the unsent
/// messages, the roster for live names, the read marker and the live subscription (`ChatViewModel+Live.swift`).
@Observable
final class ChatViewModel {
    var group: SportGroup
    var draft = MessageDraft()
    var pending: [PendingMessage] = []
    private(set) var members: [GroupMember] = []
    private(set) var isLoadingHistory = false
    private(set) var isLoadingOlder = false
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
    /// The games behind the system rows on screen, fetched once each (`ChatViewModel+Events.swift`).
    var linkedEvents: [String: SportEvent] = [:]

    let repository: any ChatRepository
    let groups: any GroupRepository
    let events: any EventRepository
    let eventChanges: ChangeTracker
    let pasteboard: any Pasteboard
    let cache: any ChatHistoryCache
    let realtime: RealtimeSessionController
    let catchUp: ChatCatchUp
    let unread: UnreadCenter
    let identity: any IdentityProvider
    let errorCenter: ErrorCenter
    let recorder: any InteractionRecorder
    let logger: any Logging
    let now: () -> Date
    let sleep: Sleep

    init(group: SportGroup,
         repository: any ChatRepository,
         groups: any GroupRepository,
         events: any EventRepository,
         eventChanges: ChangeTracker,
         pasteboard: any Pasteboard,
         cache: any ChatHistoryCache,
         realtime: RealtimeSessionController,
         catchUp: ChatCatchUp,
         unread: UnreadCenter,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep) {
        self.group = group
        self.subscribedEpoch = group.channelEpoch
        self.repository = repository
        self.groups = groups
        self.events = events
        self.eventChanges = eventChanges
        self.pasteboard = pasteboard
        self.cache = cache
        self.realtime = realtime
        self.catchUp = catchUp
        self.unread = unread
        self.identity = identity
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.now = now
        self.sleep = sleep
    }

    /// The room as the cache holds it; an empty stub until the first page arrived.
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
    var canSend: Bool { draft.isValid && !isCoolingDown && !isGone }

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
        unread.markRead(groupID: group.id)
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

    func loadOlder() async {
        guard hasOlder, !isLoadingOlder, let oldest = room.oldestID else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.older(groupID: group.id, before: oldest)
            mutateRoom { $0.applyOlder(page) }
            await adoptEpoch(page.channelEpoch)
        } catch {
            report(error, during: "Loading older messages")
        }
    }

    /// The caller has seen everything on screen: the dot goes at once, the backend hears at most once per
    /// `AppConfig.Chat.readMarkFlushInterval` while the room is open, and on leaving or backgrounding.
    func noteRead() {
        unread.markRead(groupID: group.id)
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

    /// Any group-scoped answer or event carrying a newer epoch: resubscribe there, then catch up what the gap hid.
    func adoptEpoch(_ epoch: Int) async {
        guard epoch > subscribedEpoch else { return }
        logger.info(.chat, "Epoch changed for group \(group.id): \(subscribedEpoch) -> \(epoch)")
        subscribedEpoch = epoch
        mutateRoom { $0.noteEpoch(epoch) }
        let subscription = RoomSubscription(groupID: group.id, epoch: epoch)
        if liveTask != nil { realtime.setOpenRoom(subscription) }
        await realtime.ensureSubscribed(subscription)
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Catch-up after an epoch change failed for group \(group.id): \(error)")
        }
    }

    func mutateRoom(_ change: (inout ChatRoomState) -> Void) {
        var room = self.room
        change(&room)
        cache.store(room, for: group.id)
    }

    /// Cancellation stays quiet; a room the caller lost access to is dropped; everything else reaches the popup.
    func report(_ error: any Error, during step: String) {
        guard !AppError.isCancellation(error) else { return }
        logger.error(.chat, "\(step) failed in group \(group.id): \(error)")
        if let appError = error as? AppError, appError.endsRoomAccess {
            cache.drop(groupID: group.id, reason: "\(appError)")
            isGone = true
        }
        errorCenter.report(error)
    }

    private func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            if room.hasHistory {
                try await catchUp.catchUp(groupID: group.id)
            } else {
                _ = try await catchUp.loadNewest(groupID: group.id, epoch: group.channelEpoch)
            }
            await adoptEpoch(room.channelEpoch)
        } catch {
            report(error, during: "Loading messages")
        }
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
