import Foundation

/// The place bookkeeping every create draft shares (event, group, tournament): the typed name, the spot, and the two
/// markers that tell a user's choice from a proposal. The drafts store the fields; this carries the rules once, so
/// the wizard's place pages and dirty rule read every kind the same way.
nonisolated protocol PlacePickingDraft {
    var locationName: String { get set }
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

    /// A tapped suggestion fills the name and the spot at once. The spot stays a proposal, so a later reworded name
    /// moves it again, and the name it set is not geocoded twice.
    mutating func apply(_ suggestion: PlaceSuggestion) {
        (locationName, coordinate) = (suggestion.title, suggestion.coordinate)
        (suggestedName, spotPickedOnMap) = (suggestion.title, false)
    }

    /// A spot from the map picker is the user's choice: the typed name never overrides it (`PlaceResolver`), and a
    /// suggestion the name produced earlier no longer describes it. Clearing the spot changes nothing else.
    mutating func pickSpot(_ spot: Coordinate?) {
        coordinate = spot
        guard spot != nil else { return }
        (spotPickedOnMap, suggestedName) = (true, nil)
    }
}
