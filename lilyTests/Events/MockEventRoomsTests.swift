import Foundation
import Testing
@testable import lily

/// The event rooms of the mock run: the fixtures' shape in the group mock, and the event mock mirroring every create,
/// join, leave and edit into them, as the backend's transactions do.
@MainActor
struct MockEventRoomsTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRepositories() -> (groups: MockGroupRepository, events: MockEventRepository) {
        let groups = MockGroupRepository(identity: identity, logger: logger) { now }
        let events = MockEventRepository(now: now, identity: identity, logger: logger)
        events.rooms = groups
        return (groups, events)
    }

    /// Every fixture event ships its room: the pre-joined ones with the caller as member and read, the private group's
    /// game with a private room, the count and seats mirrored from the event.
    @Test func everyFixtureEventShipsItsRoom() async throws {
        let (groups, _) = makeRepositories()
        let events = MockEventFixtures.make(now: now, count: AppConfig.Events.mockFeedSize)

        for (index, event) in events.enumerated() {
            let room = try #require(groups.find(event.id) ?? groups.groups.first { $0.id == event.id },
                                    "a room for \(event.id)")
            #expect(room.isEventRoom && room.name == event.title && room.type == event.type)
            #expect(room.memberCount == event.participantCount && room.ownerName == event.hostName)
            #expect(room.maxMembers == (event.capacity.map { $0 + 1 } ?? AppConfig.Groups.maxMembers))
            #expect(!room.membersCanCreateEvents && !room.membersCanInvite && !room.hasUnread)
            #expect(room.isMember == MockEventFixtures.isInitiallyJoined(index: index))
            #expect(room.visibility == ((event.group?.isPrivate ?? false) ? .private : .public))
        }
        let sunset = try #require(groups.groups.first { $0.id == MockEventFixtures.sunsetEventID })
        #expect(sunset.lastMessageId != nil && sunset.lastMessageAt != nil, "the one room with lines")
        #expect(groups.groups.first { $0.id == "mock-event-4" }?.lastMessageId == nil, "the silent rooms start empty")
    }

    /// The roster behind an event's room: the host as owner, then the deterministic participant names.
    @Test func theRosterNamesTheHostFirst() {
        let roster = MockGroupFixtures.roster(for: MockEventFixtures.sunsetEventID, now: now)
        #expect(roster.first?.role == .owner && roster.first?.displayName == "Marta")
        #expect(roster.dropFirst().allSatisfy { $0.role == .member })
        #expect(roster.count == 5, "the host and four others; the caller is never in a roster")
    }

    /// A join enters the room, a leave drops the membership and takes the event's bumped epoch into the room, so the
    /// realtime channel rotates like the backend's.
    @Test func joinAndLeaveMirrorIntoTheRoom() async throws {
        let (groups, events) = makeRepositories()
        let doubles = "mock-event-2"

        let joined = try await events.join(eventId: doubles)
        let roomAfterJoin = try await groups.group(id: doubles)
        #expect(roomAfterJoin.isMember && roomAfterJoin.memberCount == joined.participantCount)
        #expect(roomAfterJoin.channelEpoch == 1 && joined.channelEpoch == 1)

        let left = try await events.leave(eventId: doubles)
        #expect(left.channelEpoch == 2, "a leave bumps the epoch mirror")
        let roomAfterLeave = try #require(groups.groups.first { $0.id == doubles })
        #expect(!roomAfterLeave.isMember && roomAfterLeave.memberCount == left.participantCount)
        #expect(roomAfterLeave.channelEpoch == 2, "the room follows the mirror")
        #expect(logger.hasLine(in: .groups, at: .info, mentioning: "Joined room", doubles))
        #expect(logger.hasLine(in: .groups, at: .info, mentioning: "Left room", doubles))
    }

    /// A created event registers its room, owned by the caller; an edit syncs the name into it.
    @Test func createRegistersTheRoomAndAnEditRenamesIt() async throws {
        let (groups, events) = makeRepositories()
        var draft = EventDraft(startsAt: now.addingTimeInterval(7_200))
        draft.fillRequired()

        let created = try await events.create(draft)
        let room = try await groups.group(id: created.id)
        #expect(room.isEventRoom && room.role == .owner && room.memberCount == created.participantCount)
        #expect(room.name == created.title)
        #expect(logger.hasLine(in: .groups, at: .info, mentioning: "Mock room registered", created.id))

        draft.title = "Friday five-a-side"
        let updated = try await events.update(id: created.id, draft)
        #expect(try await groups.group(id: created.id).name == updated.title, "the room follows the rename")
    }
}
