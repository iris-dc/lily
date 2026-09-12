import Foundation
@testable import lily

/// Shared test data: one user, their session and credentials.
enum TestFixtures {
    static let user = AuthUser(id: "u-1", displayName: "Test Person", email: "test@example.com")
    static let session = AuthSession(user: user)
    static let credentials = EmailCredentials(email: "jane.doe@example.com", password: "correct-horse")
}

extension SportEvent {
    /// A minimal event at the demo centre; every optional detail absent unless given, so tests state only what they test.
    static func fixture(capacity: Int = 4,
                        participants: Int = 1,
                        startsAt: Date = .now,
                        hostUserId: String? = nil,
                        isJoined: Bool? = nil,
                        description: String? = nil,
                        lookingFor: String? = nil,
                        skillLevel: SkillLevel? = nil,
                        price: Price? = nil) -> SportEvent {
        SportEvent(
            id: "e",
            title: "t",
            type: .tennis,
            startsAt: startsAt,
            location: EventLocation(name: "l", coordinate: AppConfig.Location.mockCenter),
            capacity: capacity,
            participantCount: participants,
            hostName: "h",
            hostUserId: hostUserId,
            isJoined: isJoined,
            description: description,
            lookingFor: lookingFor,
            skillLevel: skillLevel,
            price: price
        )
    }
}
