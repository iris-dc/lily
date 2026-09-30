import Foundation
import Testing
@testable import lily

/// The body of `PUT /api/events/{id}`, key for key as the backend's `UpdateEventRequest` reads it.
struct UpdateEventPayloadTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let requiredKeys: Set<String> = ["title", "type", "startsAt", "location", "capacity"]
    private static let optionalKeys: Set<String> = ["description", "lookingFor", "skillLevel", "price"]

    private func encode(_ payload: UpdateEventPayload) throws -> [String: Any] {
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The id travels in the path and the group cannot change, so neither is in the body.
    @Test func encodesEveryEditableFieldAndNeitherTheIdNorTheGroup() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.type = .tennis
        draft.capacity = 4
        draft.description = "Bring both colours"
        draft.lookingFor = "One more"
        draft.skillLevel = .intermediate
        draft.price = Decimal(string: "7.5")
        draft.group = EventGroupRef(id: "7b1c2d3e", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)

        let json = try encode(try #require(UpdateEventPayload(draft: draft)))

        #expect(Set(json.keys) == Self.requiredKeys.union(Self.optionalKeys))
        #expect(json["title"] as? String == "Thursday five-a-side")
        #expect(json["type"] as? String == "tennis")
        #expect(json["startsAt"] as? String == "2027-01-16T08:00:00Z")
        #expect(json["capacity"] as? Int == 4)
        #expect(json["skillLevel"] as? String == "intermediate")
        let location = try #require(json["location"] as? [String: Any])
        #expect(location["name"] as? String == "Test Park")
        let price = try #require(json["price"] as? [String: Any])
        #expect(price["amount"] as? Double == 7.5)
    }

    /// The backend removes an absent optional, so a blank field is left out rather than sent as `null` or blank.
    @Test func blankOptionalDetailsAndAFreePriceAreLeftOut() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.description = "  \n"
        draft.price = 0

        let payload = try #require(UpdateEventPayload(draft: draft))

        #expect(Set(try encode(payload).keys) == Self.requiredKeys)
        #expect(payload.description == nil && payload.lookingFor == nil && payload.price == nil)
    }

    @Test func textsAreTrimmed() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.title = "  Sunset 5-a-side \n"
        draft.locationName = " Riverside Pitch 2 "

        let payload = try #require(UpdateEventPayload(draft: draft))

        #expect(payload.title == "Sunset 5-a-side" && payload.location.name == "Riverside Pitch 2")
    }

    @Test func aDraftWithoutACoordinateHasNoPayload() {
        #expect(UpdateEventPayload(draft: .fixture(now: Self.now, coordinate: nil)) == nil)
    }
}
