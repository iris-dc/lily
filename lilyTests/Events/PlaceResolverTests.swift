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

    private func draft(name: String, coordinate: Coordinate?) -> EventDraft {
        var draft = EventDraft.fixture(now: EventDraftTests.now)
        draft.locationName = name
        draft.coordinate = coordinate
        return draft
    }

    @Test func aCompletePlacePassesUntouchedAndAsksNothing() async throws {
        let complete = draft(name: "Park", coordinate: spot)
        let resolved = try await resolver.resolve(complete)
        #expect(resolved == complete)
        #expect(geocoder.geocodedNames.isEmpty && geocoder.reversedCoordinates.isEmpty)
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
