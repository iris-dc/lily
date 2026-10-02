import Foundation
import Testing
@testable import lily

/// The reply quote on the wire and in the models: decoded from the contract sample, absent on every older sample,
/// dropped by a tombstone, built from a message with the excerpt cut as the backend cuts it.
struct ReplyQuoteCodingTests {
    @Test func aReplyDecodesItsQuote() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.replyMessage)

        let quote = try #require(message.replyTo)
        #expect(quote == ReplyQuote(messageId: "01J8ZK7Q9X2M4N6P8R0T2V4W6Y",
                                    senderUserId: "seed-jonas",
                                    senderName: "Jonas",
                                    excerpt: "Anyone up for a game this week?",
                                    kind: .text))
        #expect(quote.attachmentKind == nil && quote.displayText == "Anyone up for a game this week?")
        #expect(message.text == "Here" && message.clientMessageId == "9b2f3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5e")
    }

    /// A payload without `replyTo` is a plain message; every sample from before replies still decodes.
    @Test func aMessageWithoutAQuoteDecodes() throws {
        for sample in [ContractSamples.message, ContractSamples.systemMessage, ContractSamples.deletedMessage] {
            #expect(try ContractSamples.decode(ChatMessage.self, from: sample).replyTo == nil)
        }
        let page = try ContractSamples.decode(MessagePage.self, from: ContractSamples.messagePage)
        #expect(page.items.count == 2 && page.items.allSatisfy { $0.replyTo == nil })
    }

    @Test func aQuoteRoundTripsAndATombstoneDropsIt() throws {
        let quote = ReplyQuote(messageId: "m1", senderUserId: "u-2", senderName: "Marta", kind: .text, attachmentKind: .image)
        let message = ChatMessage.fixture(id: "m2", text: "Nice shot", replyTo: quote)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: JSONEncoder().encode(message))

        #expect(decoded == message && decoded.replyTo == quote)
        #expect(message.markingDeleted().replyTo == nil && message.markingDeleted().isDeleted)
    }

    /// The excerpt is the target's text within `replyExcerptLength` UTF-16 units, never splitting a character, and
    /// named after the sender as the roster knows them now; a system row has no text to quote.
    @Test func quotingAMessageCutsTheExcerptAtACharacter() {
        let limit = AppConfig.Chat.replyExcerptLength
        let long = String(repeating: "a", count: limit - 1) + "😀😀"

        let quote = ReplyQuote(quoting: .fixture(id: "m1", text: long), senderName: "Marta now")

        #expect(quote.excerpt == String(repeating: "a", count: limit - 1), "the emoji would be the 121st unit")
        #expect(quote.messageId == "m1" && quote.senderUserId == "u-2" && quote.senderName == "Marta now")
        #expect(quote.kind == .text && quote.attachmentKind == nil)
        #expect(ReplyQuote(quoting: .fixture(id: "m2", text: "short"), senderName: "Marta").excerpt == "short")
        #expect(ReplyQuote(quoting: .fixture(id: "m3", kind: .eventCreated), senderName: "Marta").excerpt == nil)
    }

    @Test func placeholdersNameTheMediaKind() {
        func quote(_ kind: AttachmentKind?) -> ReplyQuote {
            ReplyQuote(messageId: "m", senderUserId: "u", senderName: "M", attachmentKind: kind)
        }
        #expect(quote(.image).placeholder == "Photo" && quote(.video).placeholder == "Video")
        #expect(quote(.file).placeholder == "File")
        #expect(quote(nil).placeholder == nil && quote(nil).displayText.isEmpty)
        #expect(quote(.image).displayText == "Photo", "a media target without text shows its kind")
        let captioned = ReplyQuote(messageId: "m", senderUserId: "u", senderName: "M", excerpt: "words", attachmentKind: .image)
        #expect(captioned.displayText == "words")
    }

    @Test func attachmentKindsUseTheWireNames() {
        #expect(AttachmentKind(rawValue: "image") == .image && AttachmentKind(rawValue: "video") == .video)
        #expect(AttachmentKind.file.rawValue == "file" && AttachmentKind(rawValue: "gif") == nil)
    }

    /// `replyToMessageId` is omitted on a plain message, as the contract wants absent optionals, and named on a reply.
    @Test func thePayloadOmitsTheReplyKeyUnlessSet() throws {
        let plain = try keys(of: SendMessagePayload(clientMessageId: "c", text: "t"))
        let reply = try keys(of: SendMessagePayload(clientMessageId: "c", text: "t", replyToMessageId: "m1"))

        #expect(plain?.keys.sorted() == ["clientMessageId", "text"])
        #expect(reply?["replyToMessageId"] as? String == "m1")
    }

    private func keys(of payload: SendMessagePayload) throws -> [String: Any]? {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
    }
}
