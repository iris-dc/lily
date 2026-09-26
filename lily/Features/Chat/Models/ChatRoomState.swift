import Foundation

/// Everything known about one room, ordered by message id and deduplicated, with the two cursors the recovery
/// protocol needs: `displayMaxID` (the newest row rendered, moved by live envelopes and REST alike) and `restWatermark`,
/// moved only by a `newest` or `newer` page, so a live message can never hide a gap behind it: the next catch-up still
/// starts where REST last left off. A `message_deleted` that arrives before its message is kept as a tombstone.
nonisolated struct ChatRoomState: Hashable, Sendable {
    let groupID: String
    private(set) var messages: [ChatMessage] = []
    private(set) var channelEpoch: Int
    private(set) var restWatermark: String?
    private(set) var tombstonedIDs: Set<String> = []
    /// Whether history exists before the oldest message held.
    private(set) var hasOlder = false
    /// Where the page before starts when the last backward page named it (`MessagePage.nextBefore`); `nil` means
    /// before `oldestID`.
    private(set) var olderCursor: String?
    /// Whether a `newest` page was ever applied; before that the room is a live-only stub.
    private(set) var hasHistory = false

    init(groupID: String, channelEpoch: Int) {
        self.groupID = groupID
        self.channelEpoch = channelEpoch
    }

    var displayMaxID: String? { messages.last?.id }
    var oldestID: String? { messages.first?.id }
    /// The `before` of the next older page: the cursor the backend named, else the oldest message held.
    var olderPageAnchor: String? { olderCursor ?? oldestID }

    /// Inserts in id order; a duplicate is kept unless the newcomer is the deleted form; a message of another group
    /// is refused (a live envelope routed to the wrong room). Returns whether anything changed.
    @discardableResult
    mutating func insert(_ message: ChatMessage) -> Bool {
        guard message.groupId == groupID else { return false }
        let stored = tombstonedIDs.contains(message.id) ? message.markingDeleted() : message
        let index = messages.firstIndex { $0.id >= stored.id } ?? messages.endIndex
        if index < messages.endIndex, messages[index].id == stored.id {
            guard stored.isDeleted, !messages[index].isDeleted else { return false }
            messages[index] = stored
            return true
        }
        messages.insert(stored, at: index)
        return true
    }

    mutating func insert(contentsOf page: [ChatMessage]) {
        page.forEach { insert($0) }
    }

    /// Marks a message deleted, whether it is here yet or arrives later.
    mutating func markDeleted(id: String) {
        tombstonedIDs.insert(id)
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = messages[index].markingDeleted()
        }
    }

    /// The first page of a room: the newest messages, and the watermark at the newest of them.
    mutating func applyNewest(_ page: MessagePage) {
        insert(contentsOf: page.items)
        noteOlder(from: page)
        hasHistory = true
        advanceWatermark(to: page.items.last?.id)
        channelEpoch = page.channelEpoch
    }

    /// A page before the oldest message held; never moves the watermark.
    mutating func applyOlder(_ page: MessagePage) {
        insert(contentsOf: page.items)
        noteOlder(from: page)
        channelEpoch = page.channelEpoch
    }

    /// A catch-up page after the watermark, which moves to the page's continuation cursor when it names one (so a page
    /// of hidden or already-held messages still advances), else to the newest message it returned.
    mutating func applyNewer(_ page: MessagePage) {
        insert(contentsOf: page.items)
        advanceWatermark(to: page.nextAfter ?? page.items.last?.id)
        channelEpoch = page.channelEpoch
    }

    mutating func noteEpoch(_ epoch: Int) {
        channelEpoch = epoch
    }

    func contains(clientMessageID: String) -> Bool {
        messages.contains { $0.clientMessageId == clientMessageID }
    }

    /// The same room holding only its newest `limit` messages; what the cache keeps for a room nobody is looking at.
    func trimmed(toNewest limit: Int) -> ChatRoomState {
        guard messages.count > limit else { return self }
        var copy = self
        copy.messages = Array(messages.suffix(limit))
        copy.hasOlder = true
        copy.olderCursor = nil
        return copy
    }

    private mutating func noteOlder(from page: MessagePage) {
        hasOlder = page.hasMore
        olderCursor = page.hasMore ? page.nextBefore : nil
    }

    private mutating func advanceWatermark(to id: String?) {
        guard let id, id > (restWatermark ?? "") else { return }
        restWatermark = id
    }
}
