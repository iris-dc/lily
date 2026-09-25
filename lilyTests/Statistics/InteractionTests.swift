import Foundation
import Testing
@testable import lily

/// What leaves the device: ids, types and flags, in the backend's snake_case names, and never a value that could
/// place or quote the user.
struct InteractionTests {
    private static let date = Date(timeIntervalSince1970: 1_800_000_000)
    private static let dateText = "2027-01-15T08:00:00Z"

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try APIJSONCoding.makeEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func kindsUseTheBackendsSnakeCaseNames() {
        #expect(InteractionKind.eventViewed.rawValue == "event_viewed")
        #expect(InteractionKind.filterApplied.rawValue == "filter_applied")
        #expect(InteractionKind.presentationChanged.rawValue == "presentation_changed")
    }

    @Test func viewedCarriesTheEventIdTypeAndHostAndNothingElse() throws {
        let event = SportEvent.fixture(id: "evt_01", hostUserId: "host-1", price: Price(amount: 5, currencyCode: "EUR"))

        let encoded = try json(Interaction.viewed(event, at: Self.date))

        let expected: [String: String] = ["kind": "event_viewed", "occurredAt": Self.dateText, "eventId": "evt_01",
                                          "eventType": "tennis", "hostUserId": "host-1"]
        #expect(encoded as NSDictionary == expected as NSDictionary)
    }

    @Test func aFixtureWithoutAHostLeavesTheHostOut() throws {
        let encoded = try json(Interaction.viewed(.fixture(id: "evt_02"), at: Self.date))

        #expect(Set(encoded.keys) == ["kind", "occurredAt", "eventId", "eventType"])
    }

    @Test func filterSummaryCarriesTheShapeNotTheValues() throws {
        var filter = EventFilter()
        filter.types = [.tennis, .football]
        filter.maxPrice = 12.5
        filter.skillLevel = .advanced
        filter.dateWindow = .proposal()
        filter.openSpotsOnly = true

        let interaction = Interaction.filterApplied(filter, at: Self.date)

        let summary = try #require(interaction.filter)
        #expect(summary.types == ["football", "tennis"], "wire names in a fixed order")
        #expect(summary.maxDistanceMeters == AppConfig.Events.defaultFilterRadiusMeters)
        #expect(summary.hasMaxPrice && summary.hasDateWindow && summary.openSpotsOnly)
        #expect(summary.skillLevel == .advanced)
        let encoded = try json(summary)
        #expect(Set(encoded.keys)
                == ["types", "maxDistanceMeters", "hasMaxPrice", "skillLevel", "hasDateWindow", "openSpotsOnly"])
        #expect(encoded["hasMaxPrice"] as? Bool == true)
        let text = try #require(String(bytes: APIJSONCoding.makeEncoder().encode(summary), encoding: .utf8))
        #expect(!text.contains("12.5"))
    }

    @Test func absentCriteriaAreLeftOutRatherThanNull() throws {
        let encoded = try json(Interaction.filterApplied(.everything, at: Self.date))

        #expect(Set(encoded.keys) == ["kind", "occurredAt", "filter"])
        let filter = try #require(encoded["filter"] as? [String: Any])
        #expect(Set(filter.keys) == ["types", "hasMaxPrice", "hasDateWindow", "openSpotsOnly"])
        #expect((filter["types"] as? [String])?.isEmpty == true)
    }

    @Test func presentationChangedCarriesTheWireValue() throws {
        let encoded = try json(Interaction.presentationChanged(.map, at: Self.date))

        let expected: [String: String] = ["kind": "presentation_changed", "occurredAt": Self.dateText, "presentation": "map"]
        #expect(encoded as NSDictionary == expected as NSDictionary)
        #expect(EventsPresentation.list.wireValue == "list")
    }

    @Test func groupKindsUseTheBackendsSnakeCaseNames() {
        #expect(InteractionKind.groupViewed.rawValue == "group_viewed")
        #expect(InteractionKind.groupSearchPerformed.rawValue == "group_search_performed")
        #expect(InteractionKind.chatOpened.rawValue == "chat_opened")
        #expect(InteractionKind.inviteShared.rawValue == "invite_shared")
    }

    @Test func groupViewedCarriesTheIdAndVisibilityAndNothingElse() throws {
        let group = SportGroup.fixture(id: "grp_01", name: "Secret Club", visibility: .private, role: .owner)

        let encoded = try json(Interaction.groupViewed(group, at: Self.date))

        let expected: [String: String] = ["kind": "group_viewed", "occurredAt": Self.dateText,
                                          "groupId": "grp_01", "groupVisibility": "private"]
        #expect(encoded as NSDictionary == expected as NSDictionary)
    }

    @Test func groupSearchCarriesTheFlagAndTheCountNeverTheText() throws {
        let encoded = try json(Interaction.groupSearchPerformed(hasQuery: true, resultCount: 3, at: Self.date))

        #expect(Set(encoded.keys) == ["kind", "occurredAt", "hasQuery", "resultCount"])
        #expect(encoded["hasQuery"] as? Bool == true)
        #expect(encoded["resultCount"] as? Int == 3)
    }

    @Test func inviteSharedAndChatOpenedCarryTheGroupIdOnly() throws {
        for interaction in [Interaction.inviteShared(groupID: "grp_01", at: Self.date),
                            .chatOpened(groupID: "grp_01", at: Self.date)] {
            let encoded = try json(interaction)
            #expect(Set(encoded.keys) == ["kind", "occurredAt", "groupId"])
            #expect(encoded["groupId"] as? String == "grp_01")
        }
    }

    @Test func theBatchWrapsInteractionsAndTheReceiptDecodes() throws {
        let batch = try json(InteractionBatch(interactions: [.presentationChanged(.list, at: Self.date)]))
        #expect(Set(batch.keys) == ["interactions"])
        #expect((batch["interactions"] as? [[String: Any]])?.count == 1)

        let receipt = try APIJSONCoding.makeDecoder().decode(InteractionReceipt.self, from: Data(#"{"accepted":3}"#.utf8))
        #expect(receipt == InteractionReceipt(accepted: 3))
    }
}
