import Foundation
import Testing
@testable import lily

/// The body of `POST /api/events`, key for key as the backend's `CreateEventRequest` reads it.
struct CreateEventPayloadTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let requiredKeys: Set<String> = ["clientEventId", "title", "type", "startsAt", "location", "capacity"]
    private static let optionalKeys: Set<String> = ["description", "lookingFor", "skillLevel", "price", "groupId"]
    private static let kickers = EventGroupRef(id: "7b1c2d3e", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)

    /// A draft with every optional detail filled in.
    private static func makeFullDraft() -> EventDraft {
        var draft = EventDraft.fixture(now: now, clientId: "3f2504e0-4f89-11d3-9a0c-0305e82c3301")
        draft.type = .tennis
        draft.capacity = 4
        draft.description = "Bring both colours"
        draft.lookingFor = "One more"
        draft.skillLevel = .intermediate
        draft.price = Decimal(string: "7.5")
        draft.group = kickers
        return draft
    }

    /// Encoded with the app's conventions and read back as plain JSON, so the keys are checked as the wire shows them.
    private func encode(_ payload: CreateEventPayload) throws -> [String: Any] {
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func encodesEveryFieldUnderTheContractKeys() throws {
        let draft = Self.makeFullDraft()
        let payload = try #require(CreateEventPayload(draft: draft))

        let json = try encode(payload)

        #expect(Set(json.keys) == Self.requiredKeys.union(Self.optionalKeys))
        #expect(json["clientEventId"] as? String == draft.clientId)
        #expect(json["title"] as? String == "Thursday five-a-side")
        #expect(json["type"] as? String == "tennis")
        #expect(json["startsAt"] as? String == "2027-01-16T08:00:00Z")
        #expect(json["capacity"] as? Int == 4)
        #expect(json["description"] as? String == "Bring both colours")
        #expect(json["lookingFor"] as? String == "One more")
        #expect(json["skillLevel"] as? String == "intermediate")
        #expect(json["groupId"] as? String == "7b1c2d3e", "the id alone; the backend stamps name and visibility")
    }

    @Test func locationAndPriceAreNestedObjects() throws {
        let payload = try #require(CreateEventPayload(draft: Self.makeFullDraft()))
        let centre = AppConfig.Location.mockCenter

        let json = try encode(payload)

        let location = try #require(json["location"] as? [String: Any])
        #expect(location["name"] as? String == "Test Park")
        #expect(location["coordinate"] as? [String: Double] == ["latitude": centre.latitude, "longitude": centre.longitude])
        let price = try #require(json["price"] as? [String: Any])
        #expect(price["amount"] as? Double == 7.5)
        #expect(price["currencyCode"] as? String == AppConfig.Events.marketCurrencyCode)
    }

    /// The backend reads an absent field as unset; a `null` would be a validation failure, a blank a stored blank.
    @Test func blankOptionalDetailsAreLeftOutNotSentAsNull() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.description = "  \n"
        draft.lookingFor = ""
        let payload = try #require(CreateEventPayload(draft: draft))

        let json = try encode(payload)

        #expect(Set(json.keys) == Self.requiredKeys)
        #expect(payload.description == nil && payload.lookingFor == nil)
        #expect(payload.skillLevel == nil && payload.price == nil)
    }

    /// A game of its own sends no `groupId` at all: the backend reads absent as ungrouped, `null` as a validation failure.
    @Test func aGameOfItsOwnSendsNoGroupId() throws {
        let payload = try #require(CreateEventPayload(draft: .fixture(now: Self.now)))

        #expect(payload.groupId == nil)
        #expect(try encode(payload)["groupId"] == nil)
    }

    /// A missing price is free; a zero would be a paid game costing nothing.
    @Test func aFreeGameSendsNoPrice() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.price = 0
        let payload = try #require(CreateEventPayload(draft: draft))

        #expect(payload.price == nil)
        #expect(try encode(payload)["price"] == nil)
    }

    @Test func textsAreTrimmed() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.title = "  Sunset 5-a-side \n"
        draft.locationName = " Riverside Pitch 2 "
        draft.description = " Two halves "

        let payload = try #require(CreateEventPayload(draft: draft))

        #expect(payload.title == "Sunset 5-a-side")
        #expect(payload.location.name == "Riverside Pitch 2")
        #expect(payload.description == "Two halves")
    }

    @Test func aDraftWithoutACoordinateHasNoPayload() {
        #expect(CreateEventPayload(draft: .fixture(now: Self.now, coordinate: nil)) == nil)
    }

    /// The backend validates `clientEventId` against its UUID pattern and lower-cases it for the event id, so the
    /// fixture's id and a fresh draft's must both be ids it accepts as they are.
    @Test func clientEventIdIsAUUIDTheBackendAccepts() throws {
        let fresh = EventDraft(startsAt: Self.now).clientId
        let drafts = [EventDraft.fixture(now: Self.now), EventDraft.fixture(now: Self.now, clientId: fresh)]

        for draft in drafts {
            let payload = try #require(CreateEventPayload(draft: draft))
            let id = try #require(try encode(payload)["clientEventId"] as? String)
            #expect(TestFixtures.isBackendEventId(id), "\(id)")
            #expect(id == id.lowercased(), "\(id)")
        }
    }

    @Test func thePriceCarriesTheMarketCurrencyUnlessToldOtherwise() throws {
        var draft = EventDraft.fixture(now: Self.now)
        draft.price = 5

        let market = try #require(CreateEventPayload(draft: draft))
        let dollars = try #require(CreateEventPayload(draft: draft, currencyCode: "USD"))

        #expect(market.price == Price(amount: 5, currencyCode: AppConfig.Events.marketCurrencyCode))
        #expect(dollars.price?.currencyCode == "USD")
    }
}
