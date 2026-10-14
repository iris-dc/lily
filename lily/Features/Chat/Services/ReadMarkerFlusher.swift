import Foundation

/// The read marker of one room: what the caller has seen reaches the badge at once and the backend at a pace. The
/// shown id is read from the `ChatHistoryCache` (the truth every room reads, moved by live envelopes and REST alike),
/// the dot goes through `UnreadCenter` the moment a line is read, and `PUT .../read` goes out at once on opening,
/// leaving or backgrounding and at most once per `interval` while the room is open. A refused flush is bookkeeping (a
/// warning, never the popup): the id is given back so the next attempt carries it, and the interval keeps its pace so a
/// backend that refuses is not asked again at once. The backend's answer carries the room's epoch; a newer one is handed
/// to `onEpoch`, the room's to adopt (resubscribe, catch up).
final class ReadMarkerFlusher {
    /// The newest id the backend was told of; given back to the previous value when the request fails.
    private(set) var lastFlushedID: String?
    /// When the last request went out, failed or not: the interval is measured from here.
    private(set) var lastFlushAt: Date?
    /// The epoch the backend's answer carried; the room adopts a newer one (resubscribe, catch up).
    var onEpoch: ((Int) async -> Void)?
    /// A flush is waiting out the interval.
    var isWaiting: Bool { task != nil }

    private var task: Task<Void, Never>?
    private let groupID: String
    private let repository: any ChatRepository
    private let cache: any ChatHistoryCache
    private let unread: UnreadCenter
    private let logger: any Logging
    private let interval: TimeInterval
    private let now: () -> Date
    private let sleep: Sleep

    init(groupID: String,
         repository: any ChatRepository,
         cache: any ChatHistoryCache,
         unread: UnreadCenter,
         logger: any Logging,
         interval: TimeInterval = AppConfig.Chat.readMarkFlushInterval,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep) {
        self.groupID = groupID
        self.repository = repository
        self.cache = cache
        self.unread = unread
        self.logger = logger
        self.interval = interval
        self.now = now
        self.sleep = sleep
    }

    /// The room is on screen: the dot goes and the backend hears at once.
    func opened() async {
        unread.markRead(groupID: groupID, upTo: shownID)
        await flush()
    }

    /// A line was read in the open room: the dot goes at once, the backend hears within `interval` of the last request,
    /// in one flush that carries whatever is newest by then.
    func noteRead() {
        unread.markRead(groupID: groupID, upTo: shownID)
        guard task == nil, shownID != lastFlushedID else { return }
        let elapsed = lastFlushAt.map { now().timeIntervalSince($0) } ?? .infinity
        let wait = max(interval - elapsed, 0)
        // The task lets go of its slot first, or the flush would cancel the very task running it before the request.
        task = Task { [weak self, sleep] in
            if wait > 0 { guard (try? await sleep(.seconds(wait))) != nil else { return } }
            guard let self else { return }
            task = nil
            await flush()
        }
    }

    /// Leaving or backgrounding: the backend hears at once, and a flush waiting out the interval goes with it.
    func flush() async {
        task?.cancel()
        task = nil
        guard let id = shownID, id != lastFlushedID else { return }
        let previous = lastFlushedID
        lastFlushedID = id
        lastFlushAt = now()
        do {
            let marker = try await repository.markRead(groupID: groupID, messageID: id)
            logger.debug(.chat, "Read marker flushed for group \(groupID)")
            await onEpoch?(marker.channelEpoch)
        } catch {
            lastFlushedID = previous
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Read marker failed for group \(groupID): \(error)")
        }
    }

    /// After a clear: the backend dropped the caller's marker, so the first line after it is flushed at once.
    func reset() {
        lastFlushedID = nil
        lastFlushAt = nil
    }

    /// The newest row on screen, as the cache holds it; `nil` for a room not cached or without a line.
    private var shownID: String? { cache.room(for: groupID)?.displayMaxID }
}
