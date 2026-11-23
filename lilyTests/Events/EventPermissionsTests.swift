import Foundation
import Testing
@testable import lily

/// Who gets the event detail's action row: the host and participants chat (behind the flag) and invite while the
/// event has not started; guests and outsiders get nothing.
struct EventPermissionsTests {
    private let me = TestFixtures.user.id
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var upcoming: Date { now.addingTimeInterval(3_600) }

    private func permissions(for event: SportEvent, as userID: String?, chatEnabled: Bool = true) -> EventPermissions {
        EventPermissions(event: event, userID: userID, now: now, chatEnabled: chatEnabled)
    }

    @Test func aGuestGetsNothing() {
        let event = SportEvent.fixture(startsAt: upcoming, hostUserId: me, isJoined: true)
        #expect(permissions(for: event, as: nil) == .none)
    }

    @Test func chatIsForTheHostAndParticipantsWhileTheFlagIsOn() {
        #expect(permissions(for: .fixture(startsAt: upcoming, hostUserId: me), as: me).canOpenChat)
        #expect(permissions(for: .fixture(startsAt: upcoming, isJoined: true), as: me).canOpenChat)
        #expect(!permissions(for: .fixture(startsAt: upcoming), as: me).canOpenChat, "an outsider")
        #expect(!permissions(for: .fixture(startsAt: upcoming, isJoined: true), as: me, chatEnabled: false).canOpenChat)
    }

    @Test func invitingIsTheHostsAndParticipantsWhileTheEventIsUpcoming() {
        #expect(permissions(for: .fixture(startsAt: upcoming, hostUserId: me), as: me).canInvite)
        #expect(permissions(for: .fixture(startsAt: upcoming, isJoined: true), as: me).canInvite)
        #expect(!permissions(for: .fixture(startsAt: upcoming), as: me).canInvite, "an outsider")
    }

    /// Chat stays open once the game started (the room lives on); only the invites close, the backend's
    /// `EVENT_STARTED` rule.
    @Test func theStartClosesInvitesAndKeepsTheChat() {
        let started = permissions(for: .fixture(startsAt: now, isJoined: true), as: me)
        #expect(started.canOpenChat && !started.canInvite)
        let host = permissions(for: .fixture(startsAt: now.addingTimeInterval(-60), hostUserId: me), as: me)
        #expect(host.canOpenChat && !host.canInvite)
    }

    @Test func theActionRowShowsOnlyWithSomethingToOffer() {
        #expect(!EventPermissions.none.showsActionRow)
        #expect(permissions(for: .fixture(startsAt: upcoming, isJoined: true), as: me).showsActionRow)
        #expect(!permissions(for: .fixture(startsAt: now), as: me).showsActionRow, "a started game's outsider")
    }

    /// From the room's own chat the detail offers no way back into it; invites stand, and standalone keeps the chat.
    @Test func aDetailReachedFromItsChatOffersNoChat() {
        let event = SportEvent.fixture(startsAt: upcoming, isJoined: true)
        let fromChat = EventPermissions(event: event, userID: me, now: now, chatEnabled: true, context: .fromChat)
        #expect(!fromChat.canOpenChat && fromChat.canInvite && fromChat.showsActionRow)
        let started = EventPermissions(event: .fixture(startsAt: now, isJoined: true),
                                       userID: me,
                                       now: now,
                                       chatEnabled: true,
                                       context: .fromChat)
        #expect(!started.showsActionRow, "no chat from the chat and no invites after the start: nothing to offer")
        #expect(permissions(for: event, as: me).canOpenChat, "standalone keeps the chat")
    }
}
