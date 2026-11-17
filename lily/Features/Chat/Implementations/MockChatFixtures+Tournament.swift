import Foundation

/// The table-tennis tournament room's thread; a file of its own so the fixtures enum stays under the type-body limit
/// (the event thread's pattern).
nonisolated extension MockChatFixtures {
    /// One row of the table-tennis room: a line someone wrote, or a tournament note the backend would have posted
    /// (the start, a result with the names rendered server-side, a dispute), naming its match where there is one.
    private struct TournamentLine {
        let sender: String
        var kind: MessageKind = .text
        var text: String?
        var matchID: String?
    }

    /// The table-tennis tournament's room: the start, the organiser and the players sorting out round one, the first
    /// result and the disputed one (`MockTournamentFixtures`). The Kickers Cup's room shows the general lines.
    private static let tournamentLines: [TournamentLine] = [
        TournamentLine(sender: "Marta", kind: .tournamentStarted),
        TournamentLine(sender: "Marta", text: "Round one is up. Find your opponent and agree on an evening."),
        TournamentLine(sender: "Jonas", text: "Dev, Tuesday at seven? Table two."),
        TournamentLine(sender: "Dev", text: "Works for me. Bring the good balls."),
        TournamentLine(sender: "Ayşe", text: "Who has spare balls? Mine are done for."),
        TournamentLine(sender: "Noor", text: "I'll bring a box."),
        TournamentLine(sender: "Marta", kind: .matchResult, text: "Marta 3–1 Noor", matchID: "r01p001"),
        TournamentLine(sender: "Marta", text: "Three results in already. Keep them coming!"),
        TournamentLine(sender: "Ayşe", kind: .matchDisputed, text: "Noor – Ayşe", matchID: "r02p002"),
    ]
    private static let tournamentLastMessageAge: TimeInterval = 3 * .hour

    /// How many rows the table-tennis room holds; internal for the main file's `rowCount`.
    static var tournamentLineCount: Int { tournamentLines.count }

    /// The table-tennis room's rows, nine minutes apart like every room's, ending three hours before the launch; the
    /// room is the tournament, so a note's `tournamentId` is the room's id.
    static func tournamentMessages(now: Date) -> [ChatMessage] {
        let groupID = MockTournamentFixtures.tableTennisID
        let end = now.addingTimeInterval(-tournamentLastMessageAge)
        let start = end.addingTimeInterval(-Double(tournamentLines.count - 1) * secondsBetweenMessages)
        return tournamentLines.enumerated().map { index, line in
            ChatMessage(id: messageID(groupID: groupID, index: index),
                        groupId: groupID,
                        senderUserId: MockGroupFixtures.memberID(for: line.sender),
                        senderName: line.sender,
                        kind: line.kind,
                        text: line.text,
                        tournamentId: line.kind.isTournamentNote ? groupID : nil,
                        matchId: line.matchID,
                        sentAt: start.addingTimeInterval(Double(index) * secondsBetweenMessages))
        }
    }
}
