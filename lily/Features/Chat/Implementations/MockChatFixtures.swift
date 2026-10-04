import Foundation

/// The rows of a mock room: `AppConfig.Chat.mockMessagesPerRoom` text messages from three fixture members and the
/// caller, plus one system row about a game created in the group; the conversation with Marta has a few lines of its
/// own. Ids sort like ULIDs and are shared with the group fixtures, so a group's `lastMessageId` and the caller's read
/// marker name real rows.
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
    /// The direct conversation with Marta: her lines and the caller's in turn, no system row, the last three hers and
    /// unread, so the room reads as a chat between two people the moment it is opened.
    private static let conversationLines: [(fromCounterpart: Bool, text: String)] = [
        (true, "Hey! Are you coming on Sunday?"),
        (false, "Planning to. What time do you start?"),
        (false, "And is it the usual pitch?"),
        (true, "Ten, same pitch as always."),
        (true, "Bring a ball if you have one, ours went flat."),
        (true, "See you there!"),
    ]
    /// The table-tennis tournament's room: the organiser and the players sorting out round one; no system row until
    /// the tournament kinds land. The Kickers Cup's room shows the general lines.
    private static let tournamentLines: [(sender: String, text: String)] = [
        ("Marta", "Round one is up. Find your opponent and agree on an evening."),
        ("Jonas", "Dev, Tuesday at seven? Table two."),
        ("Dev", "Works for me. Bring the good balls."),
        ("Ayşe", "Who has spare balls? Mine are done for."),
        ("Noor", "I'll bring a box."),
        ("Marta", "Three results in already. Keep them coming!"),
    ]
    /// How long before the launch Marta's last line was written; the group fixture's `lastMessageAt` says the same.
    static let conversationLastMessageAge: TimeInterval = 2 * 3600
    /// Two minutes apart, within `AppConfig.Chat.groupingWindow`, so one person's consecutive lines draw as one run.
    private static let secondsBetweenConversationLines = 120.0
    /// The system row sits after this many text messages.
    private static let systemRowAfter = 5
    /// The caller's line at this index of the Kickers room answers the text row before it, so a quote is on screen
    /// the moment the room opens.
    private static let replyLineIndex = 7
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
        if groupID == MockGroupFixtures.martaConversationID {
            return conversationMessages(callerID: callerID, callerName: callerName, now: now)
        }
        if groupID == MockTournamentFixtures.tableTennisID {
            return tournamentMessages(now: now)
        }
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
            let isReply = lineIndex == replyLineIndex && groupID == MockGroupFixtures.kickersID
            let quoted = isReply ? rows.last { !$0.isSystem } : nil
            rows.append(ChatMessage(id: id,
                                    groupId: groupID,
                                    senderUserId: isCaller ? callerID : MockGroupFixtures.memberID(for: sender),
                                    senderName: isCaller ? callerName : sender,
                                    text: lines[lineIndex % lines.count],
                                    clientMessageId: isCaller ? "mock-client-\(index)" : nil,
                                    sentAt: sentAt,
                                    replyTo: quoted.map { ReplyQuote(quoting: $0, senderName: $0.senderName) }))
            lineIndex += 1
        }
        return rows
    }

    /// The conversation's lines, ending `conversationLastMessageAge` before the launch; the caller's carry client ids
    /// like every message the caller sent.
    private static func conversationMessages(callerID: String, callerName: String, now: Date) -> [ChatMessage] {
        let groupID = MockGroupFixtures.martaConversationID
        let counterpart = MockGroupFixtures.conversationCounterpart
        let end = now.addingTimeInterval(-conversationLastMessageAge)
        let start = end.addingTimeInterval(-Double(conversationLines.count - 1) * secondsBetweenConversationLines)
        return conversationLines.enumerated().map { index, line in
            ChatMessage(id: messageID(groupID: groupID, index: index),
                        groupId: groupID,
                        senderUserId: line.fromCounterpart ? counterpart.userId : callerID,
                        senderName: line.fromCounterpart ? counterpart.displayName : callerName,
                        text: line.text,
                        clientMessageId: line.fromCounterpart ? nil : "mock-client-\(index)",
                        sentAt: start.addingTimeInterval(Double(index) * secondsBetweenConversationLines))
        }
    }

    /// The table-tennis room's lines, nine minutes apart like every room's, ending three hours before the launch.
    private static func tournamentMessages(now: Date) -> [ChatMessage] {
        let groupID = MockTournamentFixtures.tableTennisID
        let end = now.addingTimeInterval(-tournamentLastMessageAge)
        let start = end.addingTimeInterval(-Double(tournamentLines.count - 1) * secondsBetweenMessages)
        return tournamentLines.enumerated().map { index, line in
            ChatMessage(id: messageID(groupID: groupID, index: index),
                        groupId: groupID,
                        senderUserId: MockGroupFixtures.memberID(for: line.sender),
                        senderName: line.sender,
                        text: line.text,
                        sentAt: start.addingTimeInterval(Double(index) * secondsBetweenMessages))
        }
    }

    private static let tournamentLastMessageAge: TimeInterval = 3 * 3600

    private static func rowCount(for groupID: String) -> Int {
        if groupID == MockGroupFixtures.martaConversationID { return conversationLines.count }
        if groupID == MockTournamentFixtures.tableTennisID { return tournamentLines.count }
        return AppConfig.Chat.mockMessagesPerRoom + (createdEvents[groupID] == nil ? 0 : 1)
    }

    private static func groupCode(_ groupID: String) -> String {
        let letters = groupID.split(separator: "-").last.map(String.init) ?? groupID
        return String(letters.uppercased().prefix(idGroupCodeLength)).padding(toLength: idGroupCodeLength,
                                                                              withPad: "0",
                                                                              startingAt: 0)
    }
}
