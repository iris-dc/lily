import Foundation
@testable import lily

/// Shared test data: one user, their session and credentials.
enum TestFixtures {
    static let user = AuthUser(id: "u-1", displayName: "Test Person", email: "test@example.com")
    static let session = AuthSession(user: user)
    static let credentials = EmailCredentials(email: "jane.doe@example.com", password: "correct-horse")
    /// Munich: far enough from `AppConfig.Location.mockCenter` that a move there rounds differently at any precision.
    static let elsewhere = Coordinate(latitude: 48.1374, longitude: 11.5755)
    /// Laurel's `CreateEventRequest.UUID_PATTERN`, copied so the contract tests prove a `clientEventId` it accepts.
    static let backendEventIdPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"

    static func isBackendEventId(_ id: String) -> Bool {
        id.range(of: backendEventIdPattern, options: .regularExpression) != nil
    }
}

extension SportEvent {
    /// A minimal event at the demo centre; every optional detail absent unless given, so tests state only what they test.
    static func fixture(id: String = "e",
                        title: String = "t",
                        capacity: Int = 4,
                        participants: Int = 1,
                        startsAt: Date = .now,
                        hostUserId: String? = nil,
                        isJoined: Bool? = nil,
                        description: String? = nil,
                        lookingFor: String? = nil,
                        skillLevel: SkillLevel? = nil,
                        price: Price? = nil) -> SportEvent {
        SportEvent(
            id: id,
            title: title,
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

extension EventDraft {
    /// A draft that passes validation: the required fields set, starting `defaultStartOffset` after `now`, at the demo
    /// centre unless told otherwise (`nil` exercises the missing-coordinate paths). The id is a lower-case UUID like a
    /// real draft's, so the bodies the contract tests assert are ones the backend accepts.
    static func fixture(now: Date = .now,
                        clientId: String = "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
                        coordinate: Coordinate? = AppConfig.Location.mockCenter) -> EventDraft {
        var draft = EventDraft(startsAt: now.addingTimeInterval(AppConfig.Events.Creation.defaultStartOffset), clientId: clientId)
        draft.title = "Thursday five-a-side"
        draft.locationName = "Test Park"
        draft.coordinate = coordinate
        return draft
    }
}
