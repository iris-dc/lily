import Foundation

/// Settles a draft's place before it is sent, so the typed name and the spot agree. Every lookup favours places around
/// the draft's spot, else the user's position, so a venue name resolves nearby. A missing spot is geocoded from the
/// name ("Gdansk" lands the game near Gdansk; `AppError.placeNotFound` when nothing answers, `AppError.network` when
/// the geocoder could not be asked, the draft kept for a correction either way). A spot the user never chose (the GPS
/// proposal) is overridden by a typed name the geocoder knows, because the name is what the host said; a failed
/// override keeps the proposal rather than blocking a venue the geocoder has never heard of. A missing name comes from
/// the geocoder, falling back to the coordinates as text, never blank. Logs outcomes only, never the text: a place
/// name is the user's content.
struct PlaceResolver {
    let geocoder: any GeocodingService
    let logger: any Logging

    /// `position` is the bias when the draft has no spot of its own: the user's, or an edited game's stored one.
    func resolve(_ draft: EventDraft, near position: Coordinate? = nil) async throws -> EventDraft {
        var resolved = draft
        let name = draft.trimmedLocationName
        if draft.coordinate == nil {
            let found = try await spot(named: name, near: position)
            (resolved.coordinate, resolved.suggestedName) = (found, name)
            logger.info(.location, "The draft's spot was geocoded from its place name")
        } else if name.isEmpty, let coordinate = draft.coordinate {
            resolved.locationName = await placeName(for: coordinate)
            logger.info(.location, "The draft's place was named after its spot")
        } else if !draft.spotPickedOnMap, !name.isEmpty, name != draft.suggestedName, let proposal = draft.coordinate,
                  let moved = try await override(proposal, by: name) {
            (resolved.coordinate, resolved.suggestedName) = (moved, name)
        }
        return resolved
    }

    /// The spot for a draft that has none; a name nothing answers to is the user's to correct, a geocoder that could
    /// not be asked is a network failure, never "Couldn't find this place".
    private func spot(named name: String, near bias: Coordinate?) async throws -> Coordinate {
        let found: Coordinate?
        do {
            found = try await geocoder.coordinate(for: name, near: bias)
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(.location, "The geocoder failed on the draft's place name; reporting a network error")
            }
            throw error
        }
        guard let found else {
            logger.warning(.location, "The draft's place name could not be geocoded; asking the user")
            throw AppError.placeNotFound
        }
        return found
    }

    /// Where the typed name moves the proposed spot, or `nil` to keep the proposal: nothing answers, or the geocoder
    /// could not be asked. The log says whether the move left the search region, the one sign of a far-off namesake.
    private func override(_ proposal: Coordinate, by name: String) async throws -> Coordinate? {
        let found: Coordinate?
        do {
            found = try await geocoder.coordinate(for: name, near: proposal)
        } catch {
            guard !AppError.isCancellation(error) else { throw error }
            logger.warning(.location, "The geocoder failed on the typed place name; the proposed spot stands")
            return nil
        }
        guard let found else {
            logger.warning(.location, "The typed place name could not be geocoded; the proposed spot stands")
            return nil
        }
        let reach = found.distance(to: proposal) <= AppConfig.Events.placeSearchRegionMeters / 2 ? "within" : "beyond"
        logger.info(.location, "The typed place name moved the draft's proposed spot \(reach) the search region")
        return found
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
