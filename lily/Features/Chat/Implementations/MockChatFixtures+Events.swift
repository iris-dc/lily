import Foundation

/// The sunset event room's thread; a file of its own so the fixtures enum stays under the type-body limit. Every
/// other event room starts empty (`rowCount`), like the just-announced badminton open's.
nonisolated extension MockChatFixtures {
    /// The host sorting out the evening, short and read on arrival (`nil` = the caller).
    static let eventRoomLines: [(sender: String?, text: String)] = [
        ("Marta", "Pitch is booked from seven, usual gate."),
        ("Jonas", "I'll bring the bibs and a pump."),
        (nil, "Count me in, leaving work at five."),
        ("Marta", "Gate code is 4311 if you're early."),
        ("Ayşe", "Perfect. See everyone at sunset."),
    ]

    /// The sunset room's rows, nine minutes apart like every room's, ending at the room's `lastMessageAt`; any other
    /// event room answers no rows.
    static func eventRoomMessages(groupID: String,
                                  callerID: String,
                                  callerName: String,
                                  lastMessageAt: Date) -> [ChatMessage] {
        guard groupID == MockEventFixtures.sunsetEventID else { return [] }
        let start = lastMessageAt.addingTimeInterval(-Double(eventRoomLines.count - 1) * secondsBetweenMessages)
        return eventRoomLines.enumerated().map { index, line in
            ChatMessage(id: messageID(groupID: groupID, index: index),
                        groupId: groupID,
                        senderUserId: line.sender.map(MockGroupFixtures.memberID(for:)) ?? callerID,
                        senderName: line.sender ?? callerName,
                        text: line.text,
                        clientMessageId: line.sender == nil ? "mock-client-\(index)" : nil,
                        sentAt: start.addingTimeInterval(Double(index) * secondsBetweenMessages))
        }
    }
}
