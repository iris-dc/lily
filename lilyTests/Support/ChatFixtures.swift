import Foundation
@testable import lily

extension ChatMessage {
    /// A text message in group `g`; ids given by tests sort as ULIDs do (plain strings compared).
    static func fixture(id: String,
                        groupID: String = "g",
                        senderUserID: String = "u-2",
                        senderName: String = "Marta",
                        kind: MessageKind = .text,
                        text: String? = "hello",
                        eventID: String? = nil,
                        clientMessageID: String? = nil,
                        sentAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
                        isDeleted: Bool = false) -> ChatMessage {
        ChatMessage(id: id,
                    groupId: groupID,
                    senderUserId: senderUserID,
                    senderName: senderName,
                    kind: kind,
                    text: kind == .text ? text : nil,
                    eventId: eventID,
                    clientMessageId: clientMessageID,
                    sentAt: sentAt,
                    isDeleted: isDeleted)
    }
}

extension MessagePage {
    static func fixture(_ messages: [ChatMessage],
                        hasMore: Bool = false,
                        epoch: Int = 1,
                        nextBefore: String? = nil,
                        nextAfter: String? = nil) -> MessagePage {
        MessagePage(items: messages, hasMore: hasMore, channelEpoch: epoch, nextBefore: nextBefore, nextAfter: nextAfter)
    }
}

extension ChatRoomState {
    /// A room that already loaded a page ending at `watermark`, as a cache would hold it.
    static func fixture(groupID: String = "g", messages: [ChatMessage] = [], epoch: Int = 1) -> ChatRoomState {
        var room = ChatRoomState(groupID: groupID, channelEpoch: epoch)
        room.applyNewest(.fixture(messages, epoch: epoch))
        return room
    }
}

/// The chat and realtime JSON exactly as the contract shows it.
extension ContractSamples {
    static let message = """
    {"id":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","senderUserId":"seed-marta",\
    "senderName":"Marta","kind":"text","text":"Thursday works for me.","clientMessageId":"3f2504e0-4f89-11d3-9a0c-0305e82c3302",\
    "sentAt":"2026-09-24T18:00:00Z","isDeleted":false}
    """
    static let systemMessage = """
    {"id":"01J8ZK7Q9X2M4N6P8R0T2V4W6Z","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","senderUserId":"seed-marta",\
    "senderName":"Marta","kind":"event_created","eventId":"evt_01J","sentAt":"2026-09-24T18:05:00Z","isDeleted":false}
    """
    static let deletedMessage = """
    {"id":"01J8ZK7Q9X2M4N6P8R0T2V4W70","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","senderUserId":"seed-jonas",\
    "senderName":"Jonas","kind":"text","sentAt":"2026-09-24T18:06:00Z","isDeleted":true}
    """
    static let messagePage = """
    {"items":[\(message),\(systemMessage)],"hasMore":true,"channelEpoch":3,"nextBefore":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y",\
    "nextAfter":null}
    """
    /// A page from a backend that does not name continuation cursors yet.
    static let messagePageWithoutCursors = #"{"items":[\#(message)],"hasMore":true,"channelEpoch":3}"#
    static let sentMessage = #"{"message":\#(message),"channelEpoch":3}"#
    static let readMarker = #"{"lastReadMessageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y","channelEpoch":3}"#
    static let messageEnvelope = #"{"type":"message","message":\#(message)}"#
    static let messageDeletedEnvelope = """
    {"type":"message_deleted","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","messageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y"}
    """
    static let memberJoinedEnvelope = """
    {"type":"member_joined","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","member":\(member),\
    "memberCount":35,"channelEpoch":3}
    """
    static let memberLeftEnvelope = """
    {"type":"member_left","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","userId":"seed-jonas",\
    "channelEpoch":4,"memberCount":33}
    """
    static let groupUpdatedEnvelope = #"{"type":"group_updated","group":\#(group)}"#
    static let groupDeletedEnvelope = #"{"type":"group_deleted","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d"}"#
    static let unknownEnvelope = #"{"type":"typing","groupId":"g1","userId":"u-2"}"#
}
