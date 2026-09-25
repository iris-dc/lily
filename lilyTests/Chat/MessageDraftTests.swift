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
    }
}
