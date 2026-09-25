import Foundation
import Testing
@testable import lily

/// The bodies of `POST /api/groups` and `PUT /api/groups/{id}`, key for key as the backend reads them.
struct GroupPayloadTests {
    private static let createKeys: Set<String> = [
        "clientGroupId", "name", "visibility", "membersCanCreateEvents", "membersCanInvite",
    ]
    private static let updateKeys: Set<String> = ["name", "membersCanCreateEvents", "membersCanInvite"]

    private static func makeFullDraft() -> GroupDraft {
        var draft = GroupDraft.fixture()
        draft.description = " Casual 5-a-side "
        draft.visibility = .private
        draft.type = .football
        draft.membersCanCreateEvents = false
        return draft
    }

    private func encode(_ payload: some Encodable) throws -> [String: Any] {
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func createEncodesEveryFieldUnderTheContractKeys() throws {
        let draft = Self.makeFullDraft()

        let json = try encode(CreateGroupPayload(draft: draft))

        #expect(Set(json.keys) == Self.createKeys.union(["description", "type"]))
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
        var draft = GroupDraft.fixture()
        draft.description = "  \n"
        draft.name = " Kreuzberg Kickers "

        let payload = CreateGroupPayload(draft: draft)

        #expect(Set(try encode(payload).keys) == Self.createKeys)
        #expect(payload.description == nil && payload.type == nil && payload.name == "Kreuzberg Kickers")
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
        #expect(Set(full.keys) == Self.updateKeys.union(["description", "type"]))
        #expect(full["type"] as? String == "football" && full["membersCanCreateEvents"] as? Bool == false)

        let minimal = try encode(UpdateGroupPayload(draft: .fixture()))
        #expect(Set(minimal.keys) == Self.updateKeys)
    }
}
