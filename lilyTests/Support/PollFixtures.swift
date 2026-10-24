import Foundation
@testable import lily

extension Poll {
    /// Tuesday (3 votes) or Thursday (1), four voters, anonymous, one answer; `myVotes` the caller's choice.
    static func fixture(myVotes: [String] = [],
                        isAnonymous: Bool = true,
                        allowsMultipleAnswers: Bool = false,
                        votes: [Int] = [3, 1],
                        totalVoters: Int = 4) -> Poll {
        let texts = ["Tuesday", "Thursday", "Saturday"]
        return Poll(question: "Which evening suits you?",
                    options: votes.enumerated().map { Option(id: String($0.offset), text: texts[$0.offset], votes: $0.element) },
                    isAnonymous: isAnonymous,
                    allowsMultipleAnswers: allowsMultipleAnswers,
                    totalVoters: totalVoters,
                    myVotes: myVotes)
    }
}

extension ChatMessage {
    /// Marta's poll in group `g`.
    static func pollFixture(id: String, groupID: String = "g", poll: Poll = .fixture()) -> ChatMessage {
        ChatMessage(id: id,
                    groupId: groupID,
                    senderUserId: "u-2",
                    senderName: "Marta",
                    kind: .poll,
                    sentAt: Date(timeIntervalSince1970: 1_800_000_000),
                    poll: poll)
    }
}

extension PinnedMessage {
    static func fixture(messageId: String = "m1", excerpt: String? = "Bring the balls") -> PinnedMessage {
        PinnedMessage(messageId: messageId,
                      senderUserId: "u-2",
                      senderName: "Marta",
                      excerpt: excerpt,
                      kind: .text,
                      attachmentKind: nil,
                      pinnedAt: Date(timeIntervalSince1970: 1_800_000_000))
    }
}

/// The polls and pins JSON exactly as the contract shows it (groups-plan/polls-pins-plan.md).
extension ContractSamples {
    static let poll = """
    {"question":"Which evening suits you?","options":[{"id":"0","text":"Tuesday","votes":3},\
    {"id":"1","text":"Thursday","votes":1}],"isAnonymous":true,"allowsMultipleAnswers":false,"totalVoters":4,\
    "myVotes":["0"]}
    """
    static let pollMessage = """
    {"id":"01J8ZK7Q9X2M4N6P8R0T2V4W72","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","senderUserId":"seed-marta",\
    "senderName":"Marta","kind":"poll","clientMessageId":"3f2504e0-4f89-11d3-9a0c-0305e82c3303",\
    "sentAt":"2026-09-24T18:08:00Z","isDeleted":false,"poll":\(poll)}
    """
    static let pinnedMessage = """
    {"messageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y","senderUserId":"seed-marta","senderName":"Marta",\
    "excerpt":"Thursday works for me.","kind":"text","pinnedAt":"2026-10-24T18:00:00Z"}
    """
    static let pinNoteMessage = """
    {"id":"01J8ZK7Q9X2M4N6P8R0T2V4W73","groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","senderUserId":"seed-jonas",\
    "senderName":"Jonas","kind":"message_pinned","sentAt":"2026-10-24T18:00:00Z","isDeleted":false,\
    "replyTo":{"messageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y","senderUserId":"seed-marta","senderName":"Marta",\
    "excerpt":"Thursday works for me.","kind":"text"}}
    """
    static let pagedPollsAndPins = """
    {"items":[\(pollMessage),\(pinNoteMessage)],"hasMore":false,"channelEpoch":3,"pollRevision":12,\
    "pins":[\(pinnedMessage)]}
    """
    static let voteResult = #"{"messageId":"01J8ZK7Q9X2M4N6P8R0T2V4W72","poll":\#(poll),"pollRevision":12}"#
    static let pollStates = #"{"items":[{"messageId":"01J8ZK7Q9X2M4N6P8R0T2V4W72","poll":\#(poll)}],"pollRevision":12}"#
    static let pollVoters = """
    {"options":[{"id":"0","voters":[{"userId":"seed-jonas","name":"Jonas"}]},{"id":"1","voters":[]}]}
    """
    static let pinList = #"{"pins":[\#(pinnedMessage)],"channelEpoch":3}"#
    static let sendPollBody = """
    {"clientMessageId":"c-1","poll":{"question":"Which evening suits you?","options":["Tuesday","Thursday"],\
    "isAnonymous":true,"allowsMultipleAnswers":false}}
    """
}
