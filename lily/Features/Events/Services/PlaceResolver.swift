import Foundation

/// Fills whichever half of a draft's place is missing before it is sent, so a typed "Gdansk" becomes a spot there (and
/// the game shows to people around it) and a bare pin gets a name. A name the geocoder cannot place throws
/// `AppError.placeNotFound`, keeping the draft for a correction; a spot without a name never fails, falling back to
/// the coordinates as text. Logs outcomes only, never the text: a place name is the user's content.
struct PlaceResolver {
    let geocoder: any GeocodingService
    let logger: any Logging

    func resolve(_ draft: EventDraft) async throws -> EventDraft {
        var resolved = draft
        if draft.coordinate == nil {
            guard let spot = await geocoder.coordinate(for: draft.trimmedLocationName) else {
                logger.warning(.location, "The draft's place name could not be geocoded; asking the user")
                throw AppError.placeNotFound
            }
            resolved.coordinate = spot
            logger.info(.location, "The draft's spot was geocoded from its place name")
        } else if draft.trimmedLocationName.isEmpty, let coordinate = draft.coordinate {
            resolved.locationName = await placeName(for: coordinate)
            logger.info(.location, "The draft's place was named after its spot")
        }
        return resolved
    }

    /// The geocoder's name when it fits the backend's cap, else the coordinates as the map row shows them: always
    /// non-blank, so the payload never earns a 400.
    private func placeName(for coordinate: Coordinate) async -> String {
        let limit = AppConfig.Events.Creation.locationNameMaxLength
        if let name = await geocoder.placeName(for: coordinate)?.nonBlankTrimmed, name.wireLength <= limit {
            return name
        }
        return AppBranding.Events.Create.coordinateText(coordinate)
    }
}
