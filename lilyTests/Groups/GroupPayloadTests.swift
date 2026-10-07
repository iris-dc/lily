import Foundation
import Testing
@testable import lily

/// The bodies of `POST /api/groups` and `PUT /api/groups/{id}`, key for key as the backend reads them.
struct GroupPayloadTests {
    private static let createKeys: Set<String> = [
        "clientGroupId", "name", "visibility", "membersCanCreateEvents", "membersCanInvite",
    ]
    private static let updateKeys: Set<String> = ["name", "membersCanCreateEvents", "membersCanInvite"]
    private static let optionalKeys: Set<String> = ["description", "type", "location"]

    private static func makeFullDraft() -> GroupDraft {
        var draft = GroupDraft.fixture()
        draft.description = " Casual 5-a-side "
        draft.visibility = .private
        draft.type = .football
        draft.membersCanCreateEvents = false
        return draft
    }

    /// A private group that names no place: every optional left out.
    private static func makeBareDraft() -> GroupDraft {
        var draft = GroupDraft.fixture()
        draft.visibility = .private
        draft.locationName = ""
        return draft
    }

    /// The place as the backend's `LocationDto` reads it: the event body's shape, key for key.
    private func expectPlace(_ json: [String: Any]) throws {
        let location = try #require(json["location"] as? [String: Any])
        let coordinate = try #require(location["coordinate"] as? [String: Any])
        #expect(Set(location.keys) == ["name", "coordinate"] && location["name"] as? String == "Görlitzer Park")
        #expect(Set(coordinate.keys) == ["latitude", "longitude"])
        #expect(coordinate["latitude"] as? Double == AppConfig.Location.mockCenter.latitude)
        #expect(coordinate["longitude"] as? Double == AppConfig.Location.mockCenter.longitude)
    }

    private func encode(_ payload: some Encodable) throws -> [String: Any] {
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func createEncodesEveryFieldUnderTheContractKeys() throws {
        let draft = Self.makeFullDraft()

        let json = try encode(CreateGroupPayload(draft: draft))

        #expect(Set(json.keys) == Self.createKeys.union(Self.optionalKeys))
        try expectPlace(json)
        #expect(json["clientGroupId"] as? String == draft.clientId)
        #expect(json["name"] as? String == "Kreuzberg Kickers")
        #expect(json["description"] as? String == "Casual 5-a-side")
        #expect(json["visibility"] as? String == "private")
        #expect(json["type"] as? String == "football")
        #expect(json["membersCanCreateEvents"] as? Bool == false)
        #expect(json["membersCanInvite"] as? Bool == true)
    }

    /// The backend reads an absent field as unset; a `null` would be a validation failure.
    @Test func createLeavesBlankOptionalsOut() throws {
        var draft = Self.makeBareDraft()
        draft.description = "  \n"
        draft.name = " Kreuzberg Kickers "

        let payload = CreateGroupPayload(draft: draft)

        #expect(Set(try encode(payload).keys) == Self.createKeys)
        #expect(payload.description == nil && payload.type == nil && payload.location == nil)
        #expect(payload.name == "Kreuzberg Kickers")
    }

    /// The backend validates `clientGroupId` against its UUID pattern and lower-cases it, like an event's.
    @Test func clientGroupIdIsAUUIDTheBackendAccepts() throws {
        for draft in [GroupDraft.fixture(), GroupDraft()] {
            let id = try #require(try encode(CreateGroupPayload(draft: draft))["clientGroupId"] as? String)
            #expect(TestFixtures.isBackendEventId(id) && id == id.lowercased(), "\(id)")
        }
    }

    /// Visibility is immutable, so the update body never carries it; the rest is the full editable set.
    @Test func updateCarriesTheEditableSetWithoutVisibilityOrId() throws {
        let full = try encode(UpdateGroupPayload(draft: Self.makeFullDraft()))
        #expect(Set(full.keys) == Self.updateKeys.union(Self.optionalKeys))
        #expect(full["type"] as? String == "football" && full["membersCanCreateEvents"] as? Bool == false)
        try expectPlace(full)

        let minimal = try encode(UpdateGroupPayload(draft: Self.makeBareDraft()))
        #expect(Set(minimal.keys) == Self.updateKeys, "a body without a place clears it: the body is the whole state")
    }
}
