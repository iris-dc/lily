import Foundation

/// Sunday Padel Crew's room, where the caller is the owner, shows both features without a backend: a public poll from
/// Marta near its end, nobody's vote yet the caller's, and Jonas's note pinning an earlier line, which the room's pins
/// list. They replace rows the room already has, so every id, the room's size and its last line stay as they were.
nonisolated extension MockChatFixtures {
    private static let pollRowFromEnd = 3
    private static let pinNoteRowFromEnd = 2
    private static let pinnedRowFromEnd = 6
    private static let pollSender = "Marta"
    private static let pinSender = "Jonas"
    private static let pollQuestion = "Which court for Sunday?"
    private static let pollOptions = ["Court 1, indoors", "Court 3", "Either works"]
    /// Who picked which option, by option id.
    private static let pollVotes: [String: [String]] = ["0": ["Jonas", "Ayşe"], "2": ["Marta"]]

    static func decorated(_ rows: [ChatMessage], groupID: String) -> [ChatMessage] {
        guard groupID == MockGroupFixtures.padelID, rows.count > pinnedRowFromEnd else { return rows }
        var rows = rows
        let pollIndex = rows.count - pollRowFromEnd
        rows[pollIndex] = pollMessage(replacing: rows[pollIndex])
        let pinned = rows[rows.count - pinnedRowFromEnd]
        let noteIndex = rows.count - pinNoteRowFromEnd
        rows[noteIndex] = pinNote(replacing: rows[noteIndex], pinning: pinned)
        return rows
    }

    /// The room's pins as its fixture rows have them: the line Jonas's note pinned.
    static func pins(in rows: [ChatMessage]) -> [PinnedMessage] {
        rows.filter { $0.kind == .messagePinned }.compactMap { note in
            note.replyTo.map { PinnedMessage(quote: $0, pinnedAt: note.sentAt) }
        }
    }

    /// The fixture voters of each public poll in `rows`, by message id and option id.
    static func pollVoters(in rows: [ChatMessage]) -> [String: [String: [PollVoters.Voter]]] {
        var voters: [String: [String: [PollVoters.Voter]]] = [:]
        for row in rows where row.poll?.isAnonymous == false {
            voters[row.id] = pollVotes.mapValues { names in
                names.map { PollVoters.Voter(userId: MockGroupFixtures.memberID(for: $0), name: $0) }
            }
        }
        return voters
    }

    private static func pollMessage(replacing row: ChatMessage) -> ChatMessage {
        let options = pollOptions.enumerated().map { index, text in
            Poll.Option(id: String(index), text: text, votes: pollVotes[String(index)]?.count ?? 0)
        }
        let poll = Poll(question: pollQuestion,
                        options: options,
                        isAnonymous: false,
                        allowsMultipleAnswers: false,
                        totalVoters: pollVotes.values.reduce(0) { $0 + $1.count },
                        myVotes: [])
        return ChatMessage(id: row.id,
                           groupId: row.groupId,
                           senderUserId: MockGroupFixtures.memberID(for: pollSender),
                           senderName: pollSender,
                           kind: .poll,
                           sentAt: row.sentAt,
                           poll: poll)
    }

    private static func pinNote(replacing row: ChatMessage, pinning pinned: ChatMessage) -> ChatMessage {
        ChatMessage(id: row.id,
                    groupId: row.groupId,
                    senderUserId: MockGroupFixtures.memberID(for: pinSender),
                    senderName: pinSender,
                    kind: .messagePinned,
                    sentAt: row.sentAt,
                    replyTo: ReplyQuote(quoting: pinned, senderName: pinned.senderName))
    }
}
