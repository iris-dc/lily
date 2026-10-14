import Foundation
import Testing
@testable import lily

/// The read marker of one room, apart from the screen: the dot goes the moment a line is read, the backend hears at
/// once on opening and leaving and at the interval's pace in between, and a refusal is bookkeeping, never the popup.
@MainActor
struct ReadMarkerFlusherTests {
    private let interval = AppConfig.Chat.readMarkFlushInterval
    private let chat: FakeChatRepository
    private let unread: UnreadCenter
    private let logger: SpyLogger
    private let clock: DateClock
    private let sleep: HeldSleep
    private let cache: InMemoryChatHistoryCache
    private let flusher: ReadMarkerFlusher

    init() {
        let chat = FakeChatRepository()
        let unread = UnreadCenter()
        let logger = SpyLogger()
        let clock = DateClock()
        let sleep = HeldSleep()
        let cache = InMemoryChatHistoryCache(logger: logger)
        self.chat = chat
        self.unread = unread
        self.logger = logger
        self.clock = clock
        self.sleep = sleep
        self.cache = cache
        flusher = ReadMarkerFlusher(groupID: "g",
                                    repository: chat,
                                    cache: cache,
                                    unread: unread,
                                    logger: logger,
                                    now: { clock.now },
                                    sleep: { try await sleep.sleep(for: $0) })
    }

    @Test func openingFlushesWhatIsShownAndClearsTheDot() async {
        seedRoom(with: "m1")
        unread.markUnread(groupID: "g", messageID: "m1")

        await flusher.opened()

        #expect(chat.readMarks.map(\.groupID) == ["g"] && chat.readMarks.map(\.messageID) == ["m1"])
        #expect(!unread.hasUnread(groupID: "g"))
        #expect(flusher.lastFlushedID == "m1" && flusher.lastFlushAt == clock.now)
        #expect(logger.messages(in: .chat, at: .debug) == ["Read marker flushed for group g"])
    }

    /// A room never cached shows nothing: the dot still goes, the backend has nothing to hear.
    @Test func openingAnEmptyRoomSendsNothing() async {
        unread.markUnread(groupID: "g", messageID: "m1")

        await flusher.opened()

        #expect(chat.readMarks.isEmpty)
        #expect(flusher.lastFlushedID == nil && flusher.lastFlushAt == nil)
        #expect(!unread.hasUnread(groupID: "g"))
    }

    /// Lines read within the interval of the last request share one flush, which carries whatever is newest when it goes.
    @Test func aReadWithinTheIntervalWaitsAndOneFlushCarriesTheNewestID() async {
        seedRoom(with: "m1")
        await flusher.opened()
        insert("m2")

        flusher.noteRead()
        await settle(until: { sleep.held == [.seconds(interval)] })
        insert("m3")
        flusher.noteRead()

        #expect(sleep.requested == [.seconds(interval)], "the second read joins the waiting flush")
        #expect(chat.readMarks.count == 1 && flusher.isWaiting)

        clock.advance(by: interval)
        sleep.release { $0 == .seconds(interval) }
        await settle(until: { chat.readMarks.count == 2 })
        #expect(chat.readMarks.last?.messageID == "m3" && !flusher.isWaiting)
    }

    @Test func aReadAfterTheIntervalFlushesWithoutWaiting() async {
        seedRoom(with: "m1")
        await flusher.opened()
        clock.advance(by: interval)
        insert("m2")

        flusher.noteRead()

        await settle(until: { chat.readMarks.count == 2 })
        #expect(chat.readMarks.last?.messageID == "m2" && sleep.requested.isEmpty)
    }

    @Test func aReadOfWhatWasAlreadyFlushedSchedulesNothing() async {
        seedRoom(with: "m1")
        await flusher.opened()

        flusher.noteRead()
        await yield()

        #expect(sleep.requested.isEmpty && chat.readMarks.count == 1 && !flusher.isWaiting)
    }

    @Test func leavingFlushesAtOnceAndDropsTheWait() async {
        seedRoom(with: "m1")
        await flusher.opened()
        insert("m2")
        flusher.noteRead()
        await settle(until: { sleep.held == [.seconds(interval)] })

        await flusher.flush()

        #expect(chat.readMarks.map(\.messageID) == ["m1", "m2"] && !flusher.isWaiting)
        sleep.release { $0 == .seconds(interval) }
        await yield()
        #expect(chat.readMarks.count == 2, "the waiting attempt went with the flush and sends nothing more")
    }

    /// A refused marker gives its id back for the next attempt and keeps the interval's pace: the backend that refused
    /// is not asked again at once, and nothing reaches the room's epoch.
    @Test func aFailedFlushKeepsTheIntervalAndTheIDForTheNextAttempt() async {
        seedRoom(with: "m1")
        chat.readMarkerError = AppError.network
        var epochs: [Int] = []
        flusher.onEpoch = { epochs.append($0) }

        await flusher.opened()

        #expect(chat.readMarks.map(\.messageID) == ["m1"])
        #expect(flusher.lastFlushedID == nil && flusher.lastFlushAt == clock.now)
        #expect(logger.messages(in: .chat, at: .warning) == ["Read marker failed for group g: network"])
        #expect(epochs.isEmpty)

        chat.readMarkerError = nil
        flusher.noteRead()
        await settle(until: { sleep.held == [.seconds(interval)] })
        #expect(chat.readMarks.count == 1, "the refused flush is not repeated at once")

        clock.advance(by: interval)
        sleep.release { $0 == .seconds(interval) }
        await settle(until: { chat.readMarks.map(\.messageID) == ["m1", "m1"] })
        #expect(flusher.lastFlushedID == "m1")
    }

    @Test func aNewerEpochInTheAnswerIsHandedOn() async {
        seedRoom(with: "m1")
        chat.responseEpoch = 3
        var epochs: [Int] = []
        flusher.onEpoch = { epochs.append($0) }

        await flusher.opened()

        #expect(epochs == [3])
    }

    /// After a clear the backend holds no marker for the caller, so the first line read after it goes out at once.
    @Test func resetMakesTheNextReadFlushAtOnce() async {
        seedRoom(with: "m1")
        await flusher.opened()

        flusher.reset()

        #expect(flusher.lastFlushedID == nil && flusher.lastFlushAt == nil)
        insert("m2")
        flusher.noteRead()
        await settle(until: { chat.readMarks.map(\.messageID) == ["m1", "m2"] })
        #expect(sleep.requested.isEmpty)
    }

    /// Room "g" as a cache holds it after its first page, ending at `id`.
    private func seedRoom(with id: String) {
        cache.store(.fixture(groupID: "g", messages: [.fixture(id: id, groupID: "g")]), for: "g")
    }

    /// A line landing in the cached room, as a live envelope or a page would put it there.
    private func insert(_ id: String) {
        cache.update(groupID: "g") { $0.insert(.fixture(id: id, groupID: "g")) }
    }

    private func yield() async {
        for _ in 0..<20 { await Task.yield() }
    }
}
