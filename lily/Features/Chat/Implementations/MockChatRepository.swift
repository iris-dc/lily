import Foundation

/// Chat without a backend: fixture rooms for the caller's groups, sends that echo back over the mock realtime bus
/// after `AppConfig.Chat.mockEchoDelay`, and, when asked (`-mock-chat-replies`), rooms of `mockLongRoomMessages`
/// rows and a fixture member who answers after `mockAutoReplyDelay`. A clear moves the caller's floor past every
/// stored row (`floors`), and hides a conversation from Mine until any new line, the caller's included, brings it back.
/// Attachments live in `MockAttachmentStore` (`MockChatRepository+Attachments.swift`).
final class MockChatRepository: ChatRepository {
    /// Stored state is internal, not private, so `MockChatRepository+Attachments.swift` can reach it.
    var rooms: [String: [ChatMessage]] = [:]
    /// The caller's history floor per room: pages show only the ids above it.
    var floors: [String: String] = [:]
    private var replyIndex = 0
    private var sequence = 0
    let groups: MockGroupRepository
    private let transport: MockRealtimeTransport
    let identity: any IdentityProvider
    let logger: any Logging
    /// The bucket's stand-in, shared with the mock uploader and the loader's URL protocol.
    let attachments: MockAttachmentStore
    /// Whether a fixture member answers every send (`-mock-chat-replies`).
    let autoReplies: Bool
    let now: () -> Date
    private let sleep: Sleep

    init(groups: MockGroupRepository,
         transport: MockRealtimeTransport,
         identity: any IdentityProvider,
         logger: any Logging,
         attachments: MockAttachmentStore = MockAttachmentStore(),
         autoReplies: Bool = false,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep) {
        self.groups = groups
        self.transport = transport
        self.identity = identity
        self.logger = logger
        self.attachments = attachments
        self.autoReplies = autoReplies
        self.now = now
        self.sleep = sleep
    }

    func newest(groupID: String) async throws -> MessagePage {
        let (group, messages) = try await visibleRoom(groupID)
        let size = AppConfig.Chat.historyPageSize
        return MessagePage(items: Array(messages.suffix(size)), hasMore: messages.count > size, channelEpoch: group.channelEpoch)
    }

    func older(groupID: String, before messageID: String) async throws -> MessagePage {
        let (group, messages) = try await visibleRoom(groupID)
        let earlier = messages.filter { $0.id < messageID }
        let size = AppConfig.Chat.historyPageSize
        return MessagePage(items: Array(earlier.suffix(size)), hasMore: earlier.count > size, channelEpoch: group.channelEpoch)
    }

    func newer(groupID: String, after messageID: String) async throws -> MessagePage {
        let (group, messages) = try await visibleRoom(groupID)
        let later = messages.filter { $0.id > messageID }
        let size = AppConfig.Chat.catchUpPageSize
        return MessagePage(items: Array(later.prefix(size)), hasMore: later.count > size, channelEpoch: group.channelEpoch)
    }

    /// Like the backend: the same client id from the same sender answers the stored message, a reply carries the
    /// quote of its target as stored here, and every attachment named must have been uploaded by the caller into
    /// this room (a blank text is fine with one, refused without). A text starting with
    /// `AppConfig.Chat.mockFailingPrefix` is never stored and fails like a lost connection.
    func send(groupID: String, _ draft: MessageDraft) async throws -> SentMessage {
        let (group, messages) = try await room(groupID)
        guard !draft.trimmedText.hasPrefix(AppConfig.Chat.mockFailingPrefix) else { throw AppError.network }
        let callerID = identity.currentUserID ?? ""
        if let stored = messages.first(where: { $0.clientMessageId == draft.clientMessageID }) {
            guard stored.senderUserId == callerID else { throw AppError.messageSendFailed }
            logger.debug(.chat, "Mock send replayed for message \(stored.id)")
            return SentMessage(message: stored, channelEpoch: group.channelEpoch)
        }
        let payload = draft.payload
        guard payload.text != nil || payload.attachments != nil else { throw AppError.messageSendFailed }
        let message = ChatMessage(id: nextID(),
                                  groupId: groupID,
                                  senderUserId: callerID,
                                  senderName: AppBranding.Groups.Create.mockOwnerName,
                                  text: payload.text,
                                  clientMessageId: draft.clientMessageID,
                                  sentAt: now(),
                                  replyTo: try replyQuote(for: draft, in: groupID, messages),
                                  attachments: try storedAttachments(payload.attachments ?? [], in: groupID, by: callerID))
        store(message, in: group)
        publish(.message(message), to: group, after: AppConfig.Chat.mockEchoDelay)
        if autoReplies { scheduleReply(in: group) }
        return SentMessage(message: message, channelEpoch: group.channelEpoch)
    }

    func delete(groupID: String, messageID: String) async throws -> ChatMessage {
        let (group, messages) = try await room(groupID)
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { throw AppError.messageNotFound }
        let message = messages[index]
        guard message.isSent(by: identity.currentUserID) || group.role?.isAdmin == true else { throw AppError.insufficientRole }
        if message.isDeleted { return message }
        let deleted = message.markingDeleted()
        rooms[groupID]?[index] = deleted
        publish(.messageDeleted(groupID: groupID, id: messageID), to: group, after: AppConfig.Chat.mockEchoDelay)
        return deleted
    }

    /// The marker lives on the group mock's membership, so Mine reflects it on the next load.
    func markRead(groupID: String, messageID: String) async throws -> ReadMarker {
        let (group, _) = try await room(groupID)
        let marker = try groups.markRead(id: groupID, messageID: messageID)
        return ReadMarker(lastReadMessageId: marker, channelEpoch: group.channelEpoch)
    }

    /// Like the backend: the caller's floor moves to now, so every row stored so far drops out of their pages while
    /// everyone else keeps it; a conversation also leaves Mine until a new line (either side's) brings it back.
    func clearHistory(groupID: String) async throws -> ClearedHistory {
        let (group, _) = try await room(groupID)
        let floor = nextID()
        floors[groupID] = floor
        if group.isDirect { groups.hideConversation(id: groupID) }
        logger.info(.chat, "Mock chat history cleared for group \(groupID)")
        return ClearedHistory(historyFloor: floor, hidden: group.isDirect, channelEpoch: group.channelEpoch)
    }

    /// The group as the caller may see it, and its rows, built on first access for the caller of that moment. Under
    /// `autoReplies` (the demo flag) rooms are deep enough to page.
    func room(_ groupID: String) async throws -> (SportGroup, [ChatMessage]) {
        let group = try await groups.group(id: groupID)
        guard group.isMember else { throw AppError.notAMember }
        if rooms[groupID] == nil {
            rooms[groupID] = MockChatFixtures.messages(groupID: groupID,
                                                       callerID: identity.currentUserID ?? "",
                                                       callerName: AppBranding.Groups.Create.mockOwnerName,
                                                       now: now(),
                                                       count: autoReplies ? AppConfig.Chat.mockLongRoomMessages : nil)
        }
        return (group, rooms[groupID] ?? [])
    }

    /// The quote a reply carries, snapshotted like the backend does: the target must be a row above the caller's floor
    /// that is not deleted (`REPLY_TARGET_NOT_FOUND` otherwise); a system row is refused as the validation failure it is.
    private func replyQuote(for draft: MessageDraft, in groupID: String, _ messages: [ChatMessage]) throws -> ReplyQuote? {
        guard let targetID = draft.replyTo?.messageId else { return nil }
        let target = messages.first { $0.id == targetID && $0.id > floors[groupID] ?? "" && !$0.isDeleted }
        guard let target else { throw AppError.replyTargetNotFound }
        guard !target.isSystem else { throw AppError.messageSendFailed }
        return ReplyQuote(quoting: target, senderName: target.senderName)
    }

    /// The room's rows above the caller's floor: what every page is cut from.
    func visibleRoom(_ groupID: String) async throws -> (SportGroup, [ChatMessage]) {
        let (group, messages) = try await room(groupID)
        let floor = floors[groupID] ?? ""
        return (group, messages.filter { $0.id > floor })
    }

    /// A new line in the room; a hidden conversation is back in Mine with it, as the backend's floor rule implies.
    private func store(_ message: ChatMessage, in group: SportGroup) {
        rooms[group.id, default: []].append(message)
        if group.isDirect { groups.unhideConversation(id: group.id) }
    }

    /// Sorts after every fixture id and after every earlier send.
    private func nextID() -> String {
        sequence += 1
        return MockChatFixtures.messageID(groupID: "send", index: Int(now().timeIntervalSince1970 * 1000) * 1000 + sequence)
    }

    private func scheduleReply(in group: SportGroup) {
        let reply = MockChatFixtures.replies[replyIndex % MockChatFixtures.replies.count]
        replyIndex += 1
        let sender = MockChatFixtures.senders[0]
        let delay = AppConfig.Chat.mockAutoReplyDelay
        Task { [weak self, sleep] in
            guard (try? await sleep(delay)) != nil, let self else { return }
            let message = ChatMessage(id: nextID(),
                                      groupId: group.id,
                                      senderUserId: MockGroupFixtures.memberID(for: sender),
                                      senderName: sender,
                                      text: reply,
                                      sentAt: now())
            store(message, in: group)
            publish(.message(message), to: group, after: .zero)
        }
    }

    /// What the backend would publish after the commit, to the room's current channel.
    private func publish(_ envelope: RealtimeEnvelope, to group: SportGroup, after delay: Duration) {
        Task { [weak self, sleep] in
            guard (try? await sleep(delay)) != nil, let self else { return }
            transport.post(envelope, to: .room(groupID: group.id, epoch: group.channelEpoch))
        }
    }
}
