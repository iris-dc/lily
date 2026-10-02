import Foundation
import Testing
@testable import lily

/// Replies against the mock backend, in a sibling file because the main suite's body is near the limit.
extension MockChatRepositoryTests {
    /// A reply stores the target's quote as the backend snapshots it, and the Kickers fixture holds one reply already.
    @Test func sendWithReplySnapshotsTheQuote() async throws {
        let repository = makeRepository()
        let rows = try await repository.newest(groupID: kickers).items
        let target = try #require(rows.first { $0.senderName == "Marta" && !$0.isSystem })
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "Count me in"
        draft.replyTo = ReplyQuote(quoting: target, senderName: "Marta")

        let sent = try await repository.send(groupID: kickers, draft)

        let expected = ReplyQuote(messageId: target.id,
                                  senderUserId: target.senderUserId,
                                  senderName: "Marta",
                                  excerpt: target.text)
        #expect(sent.message.replyTo == expected && sent.message.text == "Count me in")
        #expect(try await repository.newest(groupID: kickers).items.last?.replyTo == expected)

        let fixtureReply = try #require(rows.first { $0.replyTo != nil })
        #expect(fixtureReply.text == "I have two sets, bringing both." && fixtureReply.senderUserId == "mock-apple")
        #expect(fixtureReply.replyTo?.excerpt == "Can someone bring bibs?" && fixtureReply.replyTo?.senderName == "Marta")
        #expect(rows.contains { $0.id == fixtureReply.replyTo?.messageId }, "the quoted row is in the room")
    }

    /// A target that is unknown, deleted or below the caller's floor is `REPLY_TARGET_NOT_FOUND`; a system row is the
    /// validation failure the backend answers.
    @Test func sendWithReplyRefusesAGoneTarget() async throws {
        let repository = makeRepository()
        let rows = try await repository.newest(groupID: kickers).items
        let own = try #require(rows.first { $0.senderUserId == "mock-apple" })
        let system = try #require(rows.first { $0.isSystem })
        var draft = MessageDraft(clientMessageID: "c-2")
        draft.text = "hello?"

        draft.replyTo = .fixture(messageId: "nope")
        await #expect(throws: AppError.replyTargetNotFound) { try await repository.send(groupID: kickers, draft) }
        draft.replyTo = ReplyQuote(quoting: system, senderName: system.senderName)
        await #expect(throws: AppError.messageSendFailed) { try await repository.send(groupID: kickers, draft) }

        _ = try await repository.delete(groupID: kickers, messageID: own.id)
        draft.replyTo = ReplyQuote(quoting: own, senderName: "You")
        await #expect(throws: AppError.replyTargetNotFound) { try await repository.send(groupID: kickers, draft) }

        _ = try await repository.clearHistory(groupID: kickers)
        let marta = try #require(rows.first { $0.senderName == "Marta" && !$0.isSystem })
        draft.replyTo = ReplyQuote(quoting: marta, senderName: "Marta")
        await #expect(throws: AppError.replyTargetNotFound) { try await repository.send(groupID: kickers, draft) }
        #expect(try await repository.newest(groupID: kickers).items.isEmpty, "nothing was stored")
    }
}
