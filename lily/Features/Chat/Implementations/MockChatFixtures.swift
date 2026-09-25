import Foundation

/// The rows of a mock room: `AppConfig.Chat.mockMessagesPerRoom` text messages from three fixture members and the
/// caller, plus one system row about a game created in the group. Ids sort like ULIDs and are shared with the group
/// fixtures, so a group's `lastMessageId` and the caller's read marker name real rows.
nonisolated enum MockChatFixtures {
    static let senders = ["Marta", "Jonas", "Ayşe"]
    /// What Marta answers under `-mock-chat-replies`, in turn.
    static let replies = [
        "Sounds good, count me in.",
        "Same place as last time?",
        "I can bring a spare ball.",
        "Running ten minutes late, start without me.",
    ]
    private static let lines = [
        "Anyone up for a game this week?",
        "Thursday works for me.",
        "Same, Thursday after work.",
        "I can book the pitch for seven.",
        "Booked. Seven at the usual place.",
        "Perfect, see you all there.",
        "Can someone bring bibs?",
        "I have two sets, bringing both.",
        "Great, that settles it.",
        "Weather looks fine for once.",
        "Famous last words.",
        "Ha. See you Thursday.",
    ]
    /// The system row sits after this many text messages.
    private static let systemRowAfter = 5
    /// The game each fixture room announces; a room without one has no system row.
    private static let createdEvents: [String: (eventID: String, sender: String)] = [
        MockGroupFixtures.kickersID: ("mock-event-0", "Marta"),
        MockGroupFixtures.padelID: ("mock-event-3", "Tom"),
        MockGroupFixtures.runnersID: ("mock-event-4", "Aiko"),
    ]
    /// The last few rows are unread in the one unread fixture room.
    private static let unreadCount = 3
    private static let idPrefix = "01J8MOCK"
    private static let idDigits = 16
    private static let secondsBetweenMessages = 540.0
    private static let idGroupCodeLength = 2

    /// Sortable like a ULID: a fixed prefix, a two-symbol group code and a zero-padded sequence.
    static func messageID(groupID: String, index: Int) -> String {
        idPrefix + groupCode(groupID) + String(format: "%0\(idDigits)d", index)
    }

    static func newestMessageID(for groupID: String) -> String {
        messageID(groupID: groupID, index: rowCount(for: groupID) - 1)
    }

    static func lastReadMessageID(for groupID: String) -> String {
        messageID(groupID: groupID, index: rowCount(for: groupID) - 1 - unreadCount)
    }

    /// The room as it stands when first opened; the caller wrote every fourth message. `count` deepens a room past
    /// its fixture size (a demo of paging and scrolling); the system row keeps its place.
    static func messages(groupID: String, callerID: String, callerName: String, now: Date, count: Int? = nil) -> [ChatMessage] {
        let count = count ?? rowCount(for: groupID)
        let start = now.addingTimeInterval(-Double(count) * secondsBetweenMessages)
        var rows: [ChatMessage] = []
        var lineIndex = 0
        for index in 0..<count {
            let sentAt = start.addingTimeInterval(Double(index) * secondsBetweenMessages)
            let id = messageID(groupID: groupID, index: index)
            if index == systemRowAfter, let created = createdEvents[groupID] {
                rows.append(ChatMessage(id: id,
                                        groupId: groupID,
                                        senderUserId: MockGroupFixtures.memberID(for: created.sender),
                                        senderName: created.sender,
                                        kind: .eventCreated,
                                        eventId: created.eventID,
                                        sentAt: sentAt))
                continue
            }
            let isCaller = lineIndex % (senders.count + 1) == senders.count
            let sender = senders[lineIndex % senders.count]
            rows.append(ChatMessage(id: id,
                                    groupId: groupID,
                                    senderUserId: isCaller ? callerID : MockGroupFixtures.memberID(for: sender),
                                    senderName: isCaller ? callerName : sender,
                                    text: lines[lineIndex % lines.count],
                                    clientMessageId: isCaller ? "mock-client-\(index)" : nil,
                                    sentAt: sentAt))
            lineIndex += 1
        }
        return rows
    }

    private static func rowCount(for groupID: String) -> Int {
        AppConfig.Chat.mockMessagesPerRoom + (createdEvents[groupID] == nil ? 0 : 1)
    }

    private static func groupCode(_ groupID: String) -> String {
        let letters = groupID.split(separator: "-").last.map(String.init) ?? groupID
        return String(letters.uppercased().prefix(idGroupCodeLength)).padding(toLength: idGroupCodeLength,
                                                                              withPad: "0",
                                                                              startingAt: 0)
    }
}
