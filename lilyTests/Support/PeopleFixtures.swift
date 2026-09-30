import Foundation
@testable import lily

extension UserProfile {
    /// Marta, sharing Kreuzberg Kickers with the caller unless told otherwise.
    static func fixture(userId: String = "u-2",
                        displayName: String = "Marta",
                        sharedGroups: [GroupSummary] = [.fixture()]) -> UserProfile {
        UserProfile(userId: userId, displayName: displayName, sharedGroups: sharedGroups)
    }
}

extension GroupSummary {
    static func fixture(id: String = "g",
                        name: String = "Kreuzberg Kickers",
                        visibility: GroupVisibility = .public,
                        type: EventType? = .football,
                        memberCount: Int = 34) -> GroupSummary {
        GroupSummary(id: id, name: name, visibility: visibility, type: type, memberCount: memberCount)
    }
}

extension UserProfileDestination {
    static func fixture(userId: String = "u-2",
                        displayName: String = "Marta",
                        context: GroupDetailContext = .standalone) -> UserProfileDestination {
        UserProfileDestination(userId: userId, displayName: displayName, context: context)
    }
}

extension SportGroup {
    /// The direct conversation with Marta (`u-2`, the profile fixture's id) as the backend answers
    /// `POST /api/conversations`: kind `direct`, private, two members, named after her, the caller a member.
    static func conversationFixture(id: String = "0f6b3a1e-2c4d-5e6f-8a9b-0c1d2e3f4a5b",
                                    name: String = "Marta",
                                    counterpartID: String = "u-2",
                                    lastMessageAt: Date? = nil) -> SportGroup {
        SportGroup(id: id,
                   name: name,
                   visibility: .private,
                   ownerName: TestFixtures.user.displayName,
                   memberCount: 2,
                   maxMembers: 2,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageAt: lastMessageAt,
                   createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                   membership: GroupMembership(role: .member, joinedAt: Date(timeIntervalSince1970: 1_800_000_000)),
                   kind: .direct,
                   counterpart: Counterpart(userId: counterpartID, displayName: name))
    }
}

extension EventParticipant {
    static func fixture(userId: String = "u-2",
                        displayName: String = "Marta",
                        joinedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
                        isHost: Bool = false) -> EventParticipant {
        EventParticipant(userId: userId, displayName: displayName, joinedAt: joinedAt, isHost: isHost)
    }
}

/// The people JSON exactly as the contract shows it (people plan, section 2).
extension ContractSamples {
    /// `GET /api/users/{userId}`: the display name and the groups the caller shares with the person, sorted by name.
    static let userProfile = """
    {"userId":"seed-marta","displayName":"Marta","sharedGroups":[\
    {"id":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","name":"Kreuzberg Kickers","visibility":"public","type":"football",\
    "memberCount":34},\
    {"id":"9d8c7b6a-5f4e-4d3c-2b1a-0f9e8d7c6b5a","name":"Sunday Padel Crew","visibility":"private","memberCount":6}]}
    """
    static let ownProfileWithoutGroups = #"{"userId":"u-1","displayName":"Apple Tester","sharedGroups":[]}"#
    /// `200` of `POST /api/conversations`: a `Group` of kind `direct` with the counterpart as the caller sees them.
    static let conversation = """
    {"id":"0f6b3a1e-2c4d-5e6f-8a9b-0c1d2e3f4a5b","kind":"direct","name":"Marta","visibility":"private",\
    "ownerName":"Apple Tester","memberCount":2,"maxMembers":2,"channelEpoch":1,"membersCanCreateEvents":false,\
    "membersCanInvite":false,"createdAt":"2026-09-29T10:00:00Z",\
    "counterpart":{"userId":"seed-marta","displayName":"Marta"},\
    "membership":{"role":"member","joinedAt":"2026-09-29T10:00:00Z","hasUnread":false}}
    """
    /// `GET /api/events/{eventId}/participants`: the host first, then by join time, never paged.
    static let eventParticipants = """
    {"items":[{"userId":"seed-marta","displayName":"Marta","joinedAt":"2026-09-01T10:00:00Z","isHost":true},\
    {"userId":"u-1","displayName":"Apple Tester","joinedAt":"2026-09-02T10:00:00Z","isHost":false}]}
    """
}
