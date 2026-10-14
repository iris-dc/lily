import Foundation
import Testing
@testable import lily

struct ChatClearPromptTests {
    @Test func aGroupIsClearedForTheCallerAlone() {
        let prompt = ChatClearPrompt(group: .fixture(name: "Kreuzberg Kickers"))
        #expect(prompt.actionTitle == "Clear chat")
        #expect(prompt.title == "Clear chat history?")
        #expect(prompt.message == "The messages disappear for you only. Other members keep them.")
    }

    @Test func aConversationIsDeletedAndNamesThePerson() {
        let prompt = ChatClearPrompt(group: .conversationFixture(name: "Marta"))
        #expect(prompt.actionTitle == "Delete chat")
        #expect(prompt.title == "Delete chat with Marta?")
        #expect(prompt.message
            == "The chat disappears for you. If Marta writes again, it comes back without the old messages.")
    }

    @Test func aTournamentRoomReadsLikeAGroup() {
        let prompt = ChatClearPrompt(group: .fixture(name: "Kickers Cup", kind: .tournament))
        #expect(prompt.actionTitle == "Clear chat")
        #expect(prompt.title == "Clear chat history?")
    }

    @Test func aRoomOfAnUnknownKindReadsLikeAGroup() {
        let prompt = ChatClearPrompt(group: .fixture(kind: .unknown("poll_room")))
        #expect(prompt.actionTitle == "Clear chat")
        #expect(prompt.message == "The messages disappear for you only. Other members keep them.")
    }
}
