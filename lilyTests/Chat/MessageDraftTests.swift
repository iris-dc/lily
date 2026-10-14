import Foundation
import Testing
@testable import lily

struct MessageDraftTests {
    @Test func aBlankDraftIsEmptyAndAFullOneIsValid() {
        var draft = MessageDraft(clientMessageID: "c-1")
        #expect(draft.issues == [.empty] && !draft.isValid)

        draft.text = "  hello  "
        #expect(draft.isValid && draft.trimmedText == "hello")
        #expect(draft.payload == SendMessagePayload(clientMessageId: "c-1", text: "hello"))
    }

    /// The limit counts UTF-16 units like the backend: an emoji is two.
    @Test func lengthIsCountedInUTF16Units() {
        var draft = MessageDraft()
        draft.text = String(repeating: "a", count: AppConfig.Chat.messageMaxLength)
        #expect(draft.isValid && draft.remaining == 0)

        draft.text = String(repeating: "😀", count: AppConfig.Chat.messageMaxLength / 2 + 1)
        #expect(draft.issues == [.tooLong] && draft.remaining < 0)
    }

    @Test func aNewDraftGetsALowerCaseUUID() {
        let draft = MessageDraft()
        #expect(TestFixtures.isBackendEventId(draft.clientMessageID))
        #expect(draft.clientMessageID == draft.clientMessageID.lowercased())
    }

    @Test func aPendingMessageRebuildsTheSameDraft() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = " retry me "
        let pending = PendingMessage(draft: draft, sentAt: .now)

        #expect(pending.id == "c-1" && pending.text == "retry me")
        #expect(pending.draft.clientMessageID == "c-1" && pending.draft.trimmedText == "retry me")
        #expect(pending.replyTo == nil && pending.draft.payload.replyToMessageId == nil)
    }

    /// A reply sends its target's id; the pending bubble keeps the quote for the retry and can drop it for a retry as
    /// a plain message, keeping its id and text.
    @Test func aReplyCarriesItsTargetThroughThePayloadAndTheRetry() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "Thursday works"
        draft.replyTo = .fixture()
        #expect(draft.payload == SendMessagePayload(clientMessageId: "c-1", text: "Thursday works", replyToMessageId: "m1"))
        #expect(draft.isValid)

        let pending = PendingMessage(draft: draft, sentAt: .now)
        #expect(pending.replyTo == .fixture() && pending.draft == draft)

        let plain = pending.droppingReply()
        #expect(plain.replyTo == nil && plain.draft.payload.replyToMessageId == nil)
        #expect(plain.id == "c-1" && plain.text == "Thursday works" && plain.state == pending.state)
    }

    /// The counter shows from `counterThreshold` on, judged on the text as it would be sent: an emoji counts two, the
    /// whitespace around the words counts for nothing.
    @Test func theCounterShowsAtTheThresholdOverTheTrimmedText() {
        let threshold = AppConfig.Chat.counterThreshold
        var draft = MessageDraft()
        draft.text = String(repeating: "a", count: threshold - 1)
        #expect(!draft.showsCounter)

        draft.text = String(repeating: "a", count: threshold)
        #expect(draft.showsCounter && draft.remaining == AppConfig.Chat.messageMaxLength - threshold)

        draft.text = String(repeating: "😀", count: threshold / 2)
        #expect(draft.showsCounter)

        draft.text = "\n  " + String(repeating: "a", count: threshold) + "  "
        #expect(draft.showsCounter && draft.remaining == AppConfig.Chat.messageMaxLength - threshold)

        draft.text = "\n  " + String(repeating: "a", count: threshold - 1) + "  "
        #expect(!draft.showsCounter)
    }

    /// The limit and the counter judge the same text the payload carries: trimmed, so whitespace around the words
    /// neither fills nor overflows the limit.
    @Test func theLimitAndTheCounterJudgeTheTextAsSent() {
        let words = String(repeating: "a", count: AppConfig.Chat.messageMaxLength)
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "\n" + words + " "
        #expect(draft.isValid && draft.remaining == 0)
        #expect(draft.payload.text == words)

        draft.text = words + "a"
        #expect(draft.issues == [.tooLong] && draft.remaining == -1)
    }

    @Test func whitespaceAloneCountsForNothing() {
        var draft = MessageDraft()
        draft.text = String(repeating: " ", count: AppConfig.Chat.counterThreshold + 100)
        #expect(draft.issues == [.empty])
        #expect(draft.remaining == AppConfig.Chat.messageMaxLength && !draft.showsCounter)
    }
}
