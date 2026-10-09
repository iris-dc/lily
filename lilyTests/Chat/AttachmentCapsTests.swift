import Foundation
import Testing
@testable import lily

/// The byte caps per room: a group's are the full ones, a conversation's smaller for videos and files, pictures alike.
struct AttachmentCapsTests {
    @Test func aGroupTakesTheFullCapsAndAConversationTheSmallerOnes() {
        #expect(AttachmentCaps.group.maxBytes(for: .image) == 10 * 1024 * 1024)
        #expect(AttachmentCaps.group.maxBytes(for: .video) == 50 * 1024 * 1024)
        #expect(AttachmentCaps.group.maxBytes(for: .file) == 25 * 1024 * 1024)
        #expect(AttachmentCaps.direct.maxBytes(for: .image) == AttachmentCaps.group.maxBytes(for: .image))
        #expect(AttachmentCaps.direct.maxBytes(for: .video) == 20 * 1024 * 1024)
        #expect(AttachmentCaps.direct.maxBytes(for: .file) == 5 * 1024 * 1024)
    }

    @Test func theRoomDecides() {
        #expect(AttachmentCaps.caps(for: .fixture(id: "g", role: .member)) == .group)
        #expect(AttachmentCaps.caps(for: .fixture(id: "dm", role: .member, kind: .direct)) == .direct)
        #expect(AttachmentCaps.caps(for: .fixture(id: "t", role: .member, kind: .tournament)) == .group,
                "a tournament room is a room like a group's")
    }
}
