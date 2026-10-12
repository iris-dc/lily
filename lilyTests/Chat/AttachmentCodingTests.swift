import Foundation
import Testing
@testable import lily

/// Attachments on the wire, key for key with Laurel's strict-JSON slice tests: a message with pictures, one without,
/// the tombstone, the upload ticket, the link, and what the device sends for a ticket and for a send.
struct AttachmentCodingTests {
    @Test func anImageMessageDecodesItsAttachments() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.imageMessage)

        #expect(message.text == nil && message.hasAttachments && message.attachments.count == 1)
        let attachment = try #require(message.attachments.first)
        #expect(attachment.id == "01ARYZ6S41TSV4RRFFQ69G5FB0" && attachment.kind == .image)
        #expect(attachment.contentType == "image/jpeg" && attachment.sizeBytes == 812_345)
        #expect(attachment.width == 2048 && attachment.height == 1536 && attachment.aspectRatio.isAbout(4.0 / 3.0))
        #expect(attachment.fileName == nil && attachment.durationSeconds == nil)
        #expect(attachment.url.host() == "lily-chat.s3.eu-central-1.amazonaws.com")
        #expect(attachment.thumbnailUrl?.path().hasSuffix("/thumb") == true)
        #expect(attachment.urlExpiresAt == APIJSONCoding.parseInstant("2026-09-25T11:00:00Z"))
        #expect(attachment.url(for: .thumbnail) == attachment.thumbnailUrl && attachment.url(for: .full) == attachment.url)
        let sent = try ContractSamples.decode(SentMessage.self, from: ContractSamples.imageSentMessage)
        #expect(sent.message == message && sent.channelEpoch == 3)
    }

    /// An attachment of a kind a newer backend sends keeps its name and leaves the message decoding with every other
    /// field intact; it is no media, so it is a card under the bubble and reads as a file in a quote; and it goes back
    /// out as it came, never rewritten to a kind this build knows.
    @Test func anUnknownAttachmentKindKeepsTheMessageDecodingAndDrawsAsAFile() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: audioKinded(ContractSamples.imageMessage))

        #expect(message.id == "01ARYZ6S41TSV4RRFFQ69G5FAV" && message.kind == .text && message.attachments.count == 1)
        let attachment = try #require(message.attachments.first)
        #expect(attachment.kind == .unknown("audio") && attachment.kind.isUnknown && !attachment.kind.isMedia)
        #expect(attachment.id == "01ARYZ6S41TSV4RRFFQ69G5FB0" && attachment.sizeBytes == 812_345)
        #expect(GalleryLayout.partition(message.attachments.map(\.kind)) == GalleryLayout.Partition(media: [], files: [0]),
                "a card under the bubble, never a tile")
        #expect(ReplyQuote(quoting: message, senderName: "Marta").placeholder == "File")
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(message), encoding: .utf8))
        #expect(json.contains(#""kind":"audio""#) && !json.contains(#""kind":"file""#))
        #expect(try ContractSamples.decode(ChatMessage.self, from: json) == message)
        let sent = try ContractSamples.decode(SentMessage.self, from: audioKinded(ContractSamples.imageSentMessage))
        #expect(sent.message == message && sent.channelEpoch == 3)
    }

    /// Every sample from before attachments decodes as a message without any.
    @Test func aMessageWithoutAttachmentsDecodesAsNone() throws {
        for sample in [ContractSamples.message, ContractSamples.systemMessage, ContractSamples.deletedMessage,
                       ContractSamples.replyMessage] {
            let message = try ContractSamples.decode(ChatMessage.self, from: sample)
            #expect(message.attachments.isEmpty && !message.hasAttachments)
        }
        let page = try ContractSamples.decode(MessagePage.self, from: ContractSamples.messagePage)
        #expect(page.items.allSatisfy { $0.attachments.isEmpty })
    }

    @Test func attachmentsRoundTripAndATombstoneDropsThem() throws {
        let message = ChatMessage.fixture(id: "m1", text: nil, attachments: [.fixture()])

        let decoded = try APIJSONCoding.makeDecoder().decode(ChatMessage.self, from: APIJSONCoding.makeEncoder().encode(message))

        #expect(decoded == message)
        let tombstone = message.markingDeleted()
        #expect(tombstone.isDeleted && tombstone.attachments.isEmpty && tombstone.replyTo == nil)
    }

    /// A thumbnail that was not uploaded falls back to the full object.
    @Test func aMissingThumbnailFallsBackToTheObject() {
        let attachment = lily.Attachment.fixture(thumbnailUrl: nil)
        #expect(attachment.url(for: .thumbnail) == attachment.url)
        #expect(lily.Attachment.fixture(id: "a", url: URL(string: "https://x.test/a")!).aspectRatio.isAbout(4.0 / 3.0))
    }

    @Test func theUploadTicketDecodesItsTargets() throws {
        let ticket = try ContractSamples.decode(UploadTicket.self, from: ContractSamples.uploadTicket)

        #expect(ticket.attachmentId == "01ARYZ6S41TSV4RRFFQ69G5FB0")
        #expect(ticket.upload.url.query()?.contains("X-Amz-Signature=main") == true)
        let signed = ["Content-Type": "image/jpeg", "Content-Length": "812345", "x-amz-meta-uploader": "sub-1"]
        #expect(ticket.upload.headers == signed)
        let thumbnail = try #require(ticket.thumbnailUpload)
        #expect(thumbnail.url.path().hasSuffix("/thumb") && thumbnail.headers["Content-Length"] == "41230")
        #expect(ticket.expiresAt == APIJSONCoding.parseInstant("2026-09-25T10:15:00Z"))
    }

    @Test func theLinkDecodesAndRefreshesAnAttachment() throws {
        let link = try ContractSamples.decode(AttachmentLink.self, from: ContractSamples.attachmentLink)
        let stale = lily.Attachment.fixture(expiresAt: .distantPast)

        let fresh = stale.refreshed(with: link)

        #expect(fresh.id == stale.id && fresh.width == stale.width && fresh.sizeBytes == stale.sizeBytes)
        #expect(fresh.url == link.url && fresh.thumbnailUrl == link.thumbnailUrl && fresh.urlExpiresAt == link.urlExpiresAt)
        #expect(link.urlExpiresAt == APIJSONCoding.parseInstant("2026-09-25T11:00:00Z"))
    }

    /// The ticket request as Laurel's `UploadRequest` reads it: optionals omitted, the thumbnail nested.
    @Test func theUploadRequestEncodesTheContractKeys() throws {
        let draft = AttachmentDraft.fixture()
        let body = try #require(try json(of: draft.uploadRequest))

        #expect(body.keys.sorted() == ["clientAttachmentId", "contentType", "height", "kind", "sizeBytes", "thumbnail", "width"])
        #expect(body["clientAttachmentId"] as? String == "d1" && body["kind"] as? String == "image")
        #expect(body["sizeBytes"] as? Int == 812_345 && body["width"] as? Int == 2048)
        let thumbnail = try #require(body["thumbnail"] as? [String: Any])
        #expect(thumbnail["contentType"] as? String == "image/jpeg" && thumbnail["sizeBytes"] as? Int == 41_230)

        let bare = AttachmentDraft(clientAttachmentID: "d2",
                                   kind: .image,
                                   fileURL: draft.fileURL,
                                   contentType: "image/jpeg",
                                   sizeBytes: 9)
        #expect(try json(of: bare.uploadRequest)?.keys.sorted() == ["clientAttachmentId", "contentType", "kind", "sizeBytes"])
    }

    /// A send that is its pictures alone omits `text`; its element names the ticket's id and `hasThumbnail` always.
    @Test func theSendPayloadNamesTheRefsAndOmitsABlankText() throws {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.attachments = [.fixture(state: .uploaded(.fixture(attachmentID: "01ARYZ6S41TSV4RRFFQ69G5FB0")))]
        let body = try #require(try json(of: draft.payload))

        #expect(body.keys.sorted() == ["attachments", "clientMessageId"])
        let element = try #require((body["attachments"] as? [[String: Any]])?.first)
        #expect(element.keys.sorted() == ["attachmentId", "contentType", "hasThumbnail", "height", "kind", "sizeBytes", "width"])
        #expect(element["attachmentId"] as? String == "01ARYZ6S41TSV4RRFFQ69G5FB0" && element["hasThumbnail"] as? Bool == true)

        draft.text = "Here"
        #expect(try json(of: draft.payload)?.keys.sorted() == ["attachments", "clientMessageId", "text"])
    }

    /// The quote of a picture message names its kind, so the reply reads "Photo" where the excerpt would be.
    @Test func aQuoteOfAnImageMessageNamesTheKind() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.imageMessage)

        let quote = ReplyQuote(quoting: message, senderName: "Marta")

        #expect(quote.attachmentKind == .image && quote.excerpt == nil && quote.displayText == "Photo")
    }

    /// Variants are told apart by the cache's file suffix.
    @Test func variantsHaveDistinctFileSuffixes() {
        #expect(AttachmentVariant.full.fileSuffix.isEmpty && AttachmentVariant.thumbnail.fileSuffix == ".thumb")
    }

    /// The sample with its picture's kind replaced by one this build does not know; the message's own kind stays `text`.
    private func audioKinded(_ sample: String) throws -> String {
        let replaced = sample.replacingOccurrences(of: #""kind":"image""#, with: #""kind":"audio""#)
        try #require(replaced != sample)
        return replaced
    }

    private func json(of payload: some Encodable) throws -> [String: Any]? {
        try JSONSerialization.jsonObject(with: APIJSONCoding.makeEncoder().encode(payload)) as? [String: Any]
    }
}
