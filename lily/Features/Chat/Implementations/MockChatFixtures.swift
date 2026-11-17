import Foundation

/// The rows of a mock room: `AppConfig.Chat.mockMessagesPerRoom` text messages from three fixture members and the
/// caller, plus one system row about a game created in the group; the conversation with Marta and the sunset event
/// room have a few lines of their own, and every other event room starts empty. Ids sort like ULIDs and are shared with the group fixtures, so a group's `lastMessageId` and the caller's read
/// marker name real rows; a line written in the run (`sentMessageID`) sorts after every fixture row of its room and
/// after every earlier line of the run, as the backend's ULIDs do.
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
    /// How long before the launch Marta's last line was written; the group fixture's `lastMessageAt` says the same.
    static let conversationLastMessageAge: TimeInterval = 2 * .hour
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
    /// Internal, not private: the event and tournament threads (`+Events.swift`, `+Tournament.swift`) space their
    /// rows with it too.
    static let secondsBetweenMessages = 540.0
    private static let idGroupCodeLength = 2
    /// Above every fixture index, the deepest demo room (`AppConfig.Chat.mockLongRoomMessages`) included; `idDigits`
    /// pads both.
    private static let sentIndexBase = 1_000_000

    /// Sortable like a ULID: a fixed prefix, a two-symbol group code and a zero-padded sequence.
    static func messageID(groupID: String, index: Int) -> String {
        idPrefix + groupCode(groupID) + String(format: "%0\(idDigits)d", index)
    }

    /// The id of the `sequence`-th line written in this run: above every fixture row of the room and every earlier
    /// line of the run, like the ULIDs the backend mints. A sequence, not a clock, so an id can never land among the
    /// fixture indices whatever the time is.
    static func sentMessageID(groupID: String, sequence: Int) -> String {
        messageID(groupID: groupID, index: sentIndexBase + sequence)
    }

    static func newestMessageID(for groupID: String) -> String {
        messageID(groupID: groupID, index: rowCount(for: groupID) - 1)
    }

    /// The room's `lastMessageId` as a group fixture stamps it: nil for a room that starts with no rows.
    static func lastMessageID(for groupID: String) -> String? {
        rowCount(for: groupID) > 0 ? newestMessageID(for: groupID) : nil
    }

    static func lastReadMessageID(for groupID: String) -> String {
        messageID(groupID: groupID, index: rowCount(for: groupID) - 1 - unreadCount)
    }

    /// The sender id of the `-mock-deleted-user` fixtures; in no roster, so the stored snapshot is all a screen has.
    static let deletedUserID = "mock-user-deleted"

    /// The `-mock-deleted-user` row: a line whose sender deleted their account, stored as the backend's by-sender
    /// scrub leaves it — the placeholder name and the per-message flag — one message interval after the room's last
    /// fixture row, so it reorders nothing.
    static func deletedSenderMessage(groupID: String, after lastMessageAt: Date) -> ChatMessage {
        ChatMessage(id: messageID(groupID: groupID, index: rowCount(for: groupID)),
                    groupId: groupID,
                    senderUserId: deletedUserID,
                    senderName: AppConfig.DisplayName.backendDefault,
                    deleted: true,
                    text: "I might drop by on Thursday.",
                    sentAt: lastMessageAt.addingTimeInterval(secondsBetweenMessages))
    }

    /// The room as it stands when first opened; the caller wrote every fourth message. `count` deepens a room past
    /// its fixture size (a demo of paging and scrolling); the system row keeps its place. A room's last row is at
    /// `lastMessageAt`, the moment its group says, so opening it never moves it in Mine; a silent group's rows end at its
    /// creation, which Mine's order counts the same.
    static func messages(in group: SportGroup,
                         callerID: String,
                         callerName: String,
                         now: Date,
                         count: Int? = nil) -> [ChatMessage] {
        let lastMessageAt = group.lastMessageAt ?? group.createdAt
        if let scripted = scriptedMessages(in: group,
                                           callerID: callerID,
                                           callerName: callerName,
                                           now: now,
                                           lastMessageAt: lastMessageAt) {
            return scripted
        }
        // The just-announced badminton open's room starts empty, whatever depth a demo flag asks for.
        guard rowCount(for: group.id) > 0 else { return [] }
        return generatedMessages(groupID: group.id,
                                 callerID: callerID,
                                 callerName: callerName,
                                 lastMessageAt: lastMessageAt,
                                 count: count ?? rowCount(for: group.id))
    }

    /// The generated thread of an ordinary group room: `count` text rows with the system row and the Kickers reply
    /// quote in their places.
    private static func generatedMessages(groupID: String,
                                          callerID: String,
                                          callerName: String,
                                          lastMessageAt: Date,
                                          count: Int) -> [ChatMessage] {
        let start = lastMessageAt.addingTimeInterval(-Double(count - 1) * secondsBetweenMessages)
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
        return decorated(rows, groupID: groupID)
    }

    /// The rooms whose threads are scripted, not generated: Marta's conversation, the table-tennis tournament and
    /// the event rooms (the sunset thread; every other starts empty, keyed on the room's kind so a game created in
    /// the run gets no fixture lines either); nil for an ordinary group room.
    private static func scriptedMessages(in group: SportGroup,
                                         callerID: String,
                                         callerName: String,
                                         now: Date,
                                         lastMessageAt: Date) -> [ChatMessage]? {
        if group.id == MockGroupFixtures.martaConversationID {
            return conversationMessages(callerID: callerID, callerName: callerName, now: now)
        }
        if group.id == MockTournamentFixtures.tableTennisID {
            return tournamentMessages(now: now)
        }
        if group.isEventRoom {
            return eventRoomMessages(groupID: group.id, callerID: callerID, callerName: callerName, lastMessageAt: lastMessageAt)
        }
        return nil
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

    private static func rowCount(for groupID: String) -> Int {
        if groupID == MockGroupFixtures.martaConversationID { return conversationLines.count }
        if groupID == MockTournamentFixtures.tableTennisID { return tournamentLineCount }
        if groupID == MockTournamentFixtures.badmintonOpenID { return 0 }
        if groupID == MockEventFixtures.sunsetEventID { return eventRoomLines.count }
        if groupID.hasPrefix(MockEventFixtures.eventIDPrefix) { return 0 }
        return AppConfig.Chat.mockMessagesPerRoom + (createdEvents[groupID] == nil ? 0 : 1)
    }

    private static func groupCode(_ groupID: String) -> String {
        let letters = groupID.split(separator: "-").last.map(String.init) ?? groupID
        return String(letters.uppercased().prefix(idGroupCodeLength)).padding(toLength: idGroupCodeLength,
                                                                              withPad: "0",
                                                                              startingAt: 0)
    }
}
