import Foundation
import Testing
@testable import lily

/// The byte caps per room: a group's are the full ones, a conversation's smaller for videos; pictures and files alike.
struct AttachmentCapsTests {
    @Test func aGroupTakesTheFullCapsAndAConversationTheSmallerOnes() {
        #expect(AttachmentCaps.group.maxBytes(for: .image) == 10 * 1024 * 1024)
        #expect(AttachmentCaps.group.maxBytes(for: .video) == 50 * 1024 * 1024)
        #expect(AttachmentCaps.group.maxBytes(for: .file) == 40 * 1024 * 1024)
        #expect(AttachmentCaps.direct.maxBytes(for: .image) == AttachmentCaps.group.maxBytes(for: .image))
        #expect(AttachmentCaps.direct.maxBytes(for: .video) == 40 * 1024 * 1024)
        #expect(AttachmentCaps.direct.maxBytes(for: .file) == AttachmentCaps.group.maxBytes(for: .file))
    }

    @Test func anUnknownKindIsCappedLikeAFile() {
        #expect(AttachmentCaps.group.maxBytes(for: .unknown("audio")) == AttachmentCaps.group.maxBytes(for: .file))
        #expect(AttachmentCaps.direct.maxBytes(for: .unknown("audio")) == 40 * 1024 * 1024)
        #expect(AttachmentCaps.group.maxBytes(for: .unknown("audio")) != AttachmentCaps.group.maxBytes(for: .video))
    }

    @Test func theRoomDecides() {
        #expect(AttachmentCaps.caps(for: .fixture(id: "g", role: .member)) == .group)
        #expect(AttachmentCaps.caps(for: .fixture(id: "dm", role: .member, kind: .direct)) == .direct)
        #expect(AttachmentCaps.caps(for: .fixture(id: "t", role: .member, kind: .tournament)) == .group,
                "a tournament room is a room like a group's")
    }

    @Test func requireLetsTheCapThroughAndRefusesOneByteOver() throws {
        for kind in [AttachmentKind.image, .video, .file] {
            let cap = AttachmentCaps.group.maxBytes(for: kind)
            try AttachmentCaps.group.require(sizeBytes: cap, for: kind)
            #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
                try AttachmentCaps.group.require(sizeBytes: cap + 1, for: kind)
            }
        }
    }

    @Test func requireNamesTheCapsItJudgedBy() throws {
        let sizeBytes = AppConfig.Chat.Attachments.directVideoMaxBytes + 1

        try AttachmentCaps.group.require(sizeBytes: sizeBytes, for: .video)
        #expect(throws: AppError.attachmentTooLarge(caps: .direct)) {
            try AttachmentCaps.direct.require(sizeBytes: sizeBytes, for: .video)
        }
    }
}
