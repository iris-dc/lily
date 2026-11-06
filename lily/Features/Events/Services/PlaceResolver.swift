import Foundation

/// Settles a draft's place before it is sent, so the typed name and the spot agree. A missing spot is geocoded from
/// the name ("Gdansk" lands the game near Gdansk; `AppError.placeNotFound` when nothing answers, the draft kept for a
/// correction). A spot the user never chose (the GPS proposal) is overridden by a typed name the geocoder knows,
/// because the name is what the host said; a failed override keeps the proposal rather than blocking a venue the
/// geocoder has never heard of. A missing name comes from the geocoder, falling back to the coordinates as text,
/// never blank. Logs outcomes only, never the text: a place name is the user's content.
struct PlaceResolver {
    let geocoder: any GeocodingService
    let logger: any Logging

    func resolve(_ draft: EventDraft) async throws -> EventDraft {
        var resolved = draft
        let name = draft.trimmedLocationName
        if draft.coordinate == nil {
            guard let spot = await geocoder.coordinate(for: name) else {
                logger.warning(.location, "The draft's place name could not be geocoded; asking the user")
                throw AppError.placeNotFound
            }
            (resolved.coordinate, resolved.suggestedName) = (spot, name)
            logger.info(.location, "The draft's spot was geocoded from its place name")
        } else if name.isEmpty, let coordinate = draft.coordinate {
            resolved.locationName = await placeName(for: coordinate)
            logger.info(.location, "The draft's place was named after its spot")
        } else if !draft.spotPickedOnMap, !name.isEmpty, name != draft.suggestedName {
            if let spot = await geocoder.coordinate(for: name) {
                (resolved.coordinate, resolved.suggestedName) = (spot, name)
                logger.info(.location, "The typed place name moved the draft's proposed spot")
            } else {
                logger.warning(.location, "The typed place name could not be geocoded; the proposed spot stands")
            }
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
