import Foundation
import Testing
@testable import lily

/// The resolver that fills whichever half of a draft's place is missing before the send.
@MainActor
struct PlaceResolverTests {
    private let geocoder = FakeGeocodingService()
    private let logger = SpyLogger()
    private let spot = AppConfig.Location.mockCenter

    private var resolver: PlaceResolver { PlaceResolver(geocoder: geocoder, logger: logger) }

    /// A valid draft whose place is as given and whose spot, when there is one, is the proposal, not a pick.
    private func draft(name: String, coordinate: Coordinate?) -> EventDraft {
        var draft = EventDraft.fixture(now: EventDraftTests.now)
        draft.locationName = name
        draft.coordinate = coordinate
        draft.spotPickedOnMap = false
        draft.suggestedName = nil
        return draft
    }

    @Test func aPickedSpotPassesUntouchedAndAsksNothing() async throws {
        var complete = draft(name: "Park", coordinate: spot)
        complete.spotPickedOnMap = true
        let resolved = try await resolver.resolve(complete)
        #expect(resolved == complete)
        #expect(geocoder.geocodedNames.isEmpty && geocoder.reversedCoordinates.isEmpty)
    }

    /// The proposed spot (the GPS fix) is not the host's word; the typed name is, so it wins ("Warsaw" lands in
    /// Warsaw), and the name a suggestion already resolved is not geocoded again.
    @Test func aTypedNameMovesAProposedSpotButNotASuggestedOne() async throws {
        let warsaw = Coordinate(latitude: 52.2297, longitude: 21.0122)
        geocoder.coordinateResult = warsaw
        let typed = try await resolver.resolve(draft(name: "Warsaw", coordinate: spot))
        #expect(typed.coordinate == warsaw && typed.suggestedName == "Warsaw")

        var suggested = draft(name: "Warsaw", coordinate: warsaw)
        suggested.suggestedName = "Warsaw"
        let resolved = try await resolver.resolve(suggested)
        #expect(resolved == suggested && geocoder.geocodedNames == ["Warsaw"], "one geocode, for the typed name alone")
    }

    /// A venue the geocoder has never heard of must not block a host who has a spot: the proposal stands, logged.
    @Test func aNameTheGeocoderCannotPlaceKeepsTheProposedSpot() async throws {
        geocoder.coordinateResult = nil
        let resolved = try await resolver.resolve(draft(name: "Dave's backyard", coordinate: spot))
        #expect(resolved.coordinate == spot && resolved.suggestedName == nil)
        #expect(logger.count(in: .location, at: .warning, mentioning: "the proposed spot stands") == 1)
    }

    @Test func aMissingSpotIsGeocodedFromTheTrimmedName() async throws {
        geocoder.coordinateResult = spot
        let resolved = try await resolver.resolve(draft(name: " Gdansk ", coordinate: nil))
        #expect(resolved.coordinate == spot && geocoder.geocodedNames == ["Gdansk"])
    }

    @Test func aNameTheGeocoderCannotPlaceThrowsPlaceNotFound() async {
        geocoder.coordinateResult = nil
        await #expect(throws: AppError.placeNotFound) { _ = try await resolver.resolve(draft(name: "xyzzy", coordinate: nil)) }
        #expect(logger.count(in: .location, at: .warning, mentioning: "could not be geocoded") == 1)
    }

    /// The reverse name must survive the backend's cap; one over it falls back like none, so the payload never earns a 400.
    @Test func aMissingNameComesFromTheGeocoderOrFallsBackToTheCoordinates() async throws {
        geocoder.nameResult = "Mauerpark"
        #expect(try await resolver.resolve(draft(name: "  ", coordinate: spot)).trimmedLocationName == "Mauerpark")

        geocoder.nameResult = nil
        let bare = try await resolver.resolve(draft(name: "", coordinate: spot))
        #expect(bare.trimmedLocationName == AppBranding.Events.Create.coordinateText(spot))

        geocoder.nameResult = String(repeating: "x", count: AppConfig.Events.Creation.locationNameMaxLength + 1)
        let capped = try await resolver.resolve(draft(name: "", coordinate: spot))
        #expect(capped.trimmedLocationName == AppBranding.Events.Create.coordinateText(spot))
    }
}
