import Foundation

/// Everything known about one room, ordered by message id and deduplicated, with the two cursors the recovery
/// protocol needs: `displayMaxID` (the newest row rendered, moved by live envelopes and REST alike) and `restWatermark`,
/// moved only by a `newest` or `newer` page, so a live message can never hide a gap behind it: the next catch-up still
/// starts where REST last left off. A `message_deleted` that arrives before its message is kept as a tombstone. The
/// room's pins are the latest page's; `pollRevision` is the revision whose poll counts the room holds, so a page that
/// names a later one says the polls held need a refresh (`ChatCatchUp`).
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
    private(set) var pins: [PinnedMessage] = []
    private(set) var pollRevision = 0

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

    /// A page's messages: new ones inserted, and a poll already held takes the page's counts when the page is at least
    /// as fresh as the room (`revision`, the page's `pollRevision`): a page generated before a vote's answer landed would
    /// otherwise undo the vote, and no refresh would follow, since the room is already past the page.
    private mutating func take(_ page: [ChatMessage], revision: Int) {
        for message in page where !insert(message) {
            guard revision >= pollRevision, let poll = message.poll,
                  let index = messages.firstIndex(where: { $0.id == message.id }), !messages[index].isDeleted else { continue }
            messages[index] = messages[index].replacingPoll(poll)
        }
    }

    /// The polls' states a refresh answered at `revision`, which the room then holds.
    mutating func applyPolls(_ states: [PollState], revision: Int) {
        states.forEach { replacePoll(messageID: $0.messageId, with: $0.poll) }
        pollRevision = max(pollRevision, revision)
    }

    /// One poll's state: the caller's vote, as shown before the answer or as answered. The revision moves only when the
    /// answer's is the next one, so a vote that others' votes preceded still leaves the next catch-up a refresh to do.
    mutating func applyPoll(messageID: String, poll: Poll, revision: Int? = nil) {
        replacePoll(messageID: messageID, with: poll)
        if let revision, revision == pollRevision + 1 { pollRevision = revision }
    }

    mutating func applyPins(_ pins: [PinnedMessage]) {
        self.pins = pins
    }

    /// The live polls held, newest first, at most `limit`: what a refresh asks for.
    func pollIDs(limit: Int) -> [String] {
        Array(messages.reversed().filter { $0.poll != nil && !$0.isDeleted }.prefix(limit).map(\.id))
    }

    private mutating func replacePoll(messageID: String, with poll: Poll) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }), !messages[index].isDeleted else { return }
        messages[index] = messages[index].replacingPoll(poll)
    }

    /// Marks a message deleted, whether it is here yet or arrives later.
    mutating func markDeleted(id: String) {
        tombstonedIDs.insert(id)
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = messages[index].markingDeleted()
        }
    }

    /// Puts back a message this device tombstoned ahead of a delete the backend then refused.
    mutating func restore(_ message: ChatMessage) {
        tombstonedIDs.remove(message.id)
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }

    /// The first page of a room: the newest messages, and the watermark at the newest of them.
    mutating func applyNewest(_ page: MessagePage) {
        // A room's first page holds every poll as of the page's revision; a room held before may hold older polls.
        if !hasHistory, messages.allSatisfy({ $0.poll == nil }) { pollRevision = page.pollRevision }
        take(page.items, revision: page.pollRevision)
        pins = page.pins
        noteOlder(from: page)
        hasHistory = true
        advanceWatermark(to: page.items.last?.id)
        channelEpoch = page.channelEpoch
    }

    /// The page asked for at `anchor` (`olderPageAnchor` when the request went out); never moves the watermark.
    /// Refused, changing nothing, when the anchor moved meanwhile: the room was compacted (the trim dropped the oldest
    /// rows and forgot the cursor) or cleared, and prepending the page below rows that are gone would leave a hole
    /// nothing refills, since catch-up only moves forward. Answers whether the page was taken.
    @discardableResult
    mutating func applyOlder(_ page: MessagePage, before anchor: String) -> Bool {
        guard olderPageAnchor == anchor else { return false }
        take(page.items, revision: page.pollRevision)
        pins = page.pins
        noteOlder(from: page)
        channelEpoch = page.channelEpoch
        return true
    }

    /// A catch-up page after the watermark, which moves to the page's continuation cursor when it names one (so a page
    /// of hidden or already-held messages still advances), else to the newest message it returned.
    mutating func applyNewer(_ page: MessagePage) {
        take(page.items, revision: page.pollRevision)
        pins = page.pins
        advanceWatermark(to: page.nextAfter ?? page.items.last?.id)
        channelEpoch = page.channelEpoch
    }

    /// The caller's history floor moved to `floor`: everything at or below it is gone from their pages and nothing older
    /// exists for them, the room counts as loaded, and the watermark sits at the floor so the next catch-up asks
    /// `newer(after: floor)` (which the backend answers from the floor) and a quiet room is not caught up at all. A line
    /// that landed above the floor while the request was out stays.
    mutating func applyCleared(floor: String, epoch: Int) {
        messages.removeAll { $0.id <= floor }
        tombstonedIDs = tombstonedIDs.filter { $0 > floor }
        hasOlder = false
        olderCursor = nil
        hasHistory = true
        advanceWatermark(to: floor)
        channelEpoch = epoch
    }

    mutating func noteEpoch(_ epoch: Int) {
        channelEpoch = epoch
    }

    /// The stored message a send from this device produced, found by the client id its bubble carried.
    func message(clientMessageID: String) -> ChatMessage? {
        messages.first { $0.clientMessageId == clientMessageID }
    }

    func contains(clientMessageID: String) -> Bool {
        message(clientMessageID: clientMessageID) != nil
    }

    func contains(id: String) -> Bool {
        messages.contains { $0.id == id }
    }

    /// Whether this room knows `id` as deleted: tombstoned here, or held as a tombstone a page delivered.
    func isDeleted(id: String) -> Bool {
        tombstonedIDs.contains(id) || messages.contains { $0.id == id && $0.isDeleted }
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
