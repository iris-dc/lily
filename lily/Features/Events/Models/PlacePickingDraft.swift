import Foundation

/// The place bookkeeping every create draft shares (event, group, tournament): the typed name, the optional detail
/// line, the spot, and the two markers that tell a user's choice from a proposal. The drafts store the fields; this
/// carries the rules once, so the wizard's place pages, the edit forms and the dirty rule read every kind the same way.
nonisolated protocol PlacePickingDraft {
    var locationName: String { get set }
    /// The optional line under the address (apartment, floor, entrance): free text appended to the stored name on
    /// the wire, never judged as the place itself.
    var locationDetail: String { get set }
    var coordinate: Coordinate? { get set }
    /// Whether the user chose `coordinate` on the map (or edits a stored place): a chosen spot is the user's own,
    /// never a proposal to be overridden or read as nothing.
    var spotPickedOnMap: Bool { get set }
    /// The name whose suggestion produced `coordinate`, so the same name is not asked about twice and a changed name is.
    var suggestedName: String? { get set }
}

nonisolated extension PlacePickingDraft {
    /// The typed name worth asking for suggestions: trimmed, at least `AppConfig.Events.placeSuggestionMinimumQuery`
    /// code points, and not the name a tapped suggestion just set; `nil` asks for nothing.
    var placeSuggestionQuery: String? {
        let query = locationName.trimmed
        guard query.codePointCount >= AppConfig.Events.placeSuggestionMinimumQuery, query != suggestedName else { return nil }
        return query
    }

    /// Whether the place really was chosen (round 5): a spot set on the map (or carried in from a stored place), or
    /// a tapped suggestion whose name still reads in the field. Typed text alone never counts, so editing the name
    /// after a pick drops the choice.
    var placeChosen: Bool {
        spotPickedOnMap || (suggestedName != nil && suggestedName == locationName.trimmed)
    }

    /// The place name as the wire and the stored thing carry it: the address, then the detail line after a comma.
    /// The detail never stands alone and never decides which half of the place is there.
    var composedLocationName: String {
        guard let name = locationName.nonBlankTrimmed else { return "" }
        guard let detail = locationDetail.nonBlankTrimmed else { return name }
        return "\(name), \(detail)"
    }

    /// The wire units the detail line appends to the stored name; what a reverse-geocoded address must leave room for.
    var locationDetailReserve: Int {
        locationDetail.nonBlankTrimmed.map { ", \($0)".wireLength } ?? 0
    }

    /// A tapped suggestion fills the name and the spot at once. The spot stays a proposal, so a later reworded name
    /// moves it again, and the name it set is not geocoded twice.
    mutating func apply(_ suggestion: PlaceSuggestion) {
        (locationName, coordinate) = (suggestion.title, suggestion.coordinate)
        (suggestedName, spotPickedOnMap) = (suggestion.title, false)
    }

    /// A spot from the map picker is the user's choice: the typed name never overrides it (`PlaceResolver`), and a
    /// suggestion the name produced earlier no longer describes it. Clearing the spot clears the map-pick mark with
    /// it — nothing cannot be a chosen spot — and keeps the name bookkeeping.
    mutating func pickSpot(_ spot: Coordinate?) {
        coordinate = spot
        guard spot != nil else {
            spotPickedOnMap = false
            return
        }
        (spotPickedOnMap, suggestedName) = (true, nil)
    }
}
