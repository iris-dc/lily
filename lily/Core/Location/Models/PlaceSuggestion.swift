import Foundation

/// One place the geocoder offers for a typed query: what to call it, where it is, and a line placing it ("Warsaw,
/// Poland"). Picking one fills the draft's name and spot at once.
nonisolated struct PlaceSuggestion: Identifiable, Equatable, Sendable {
    let title: String
    let subtitle: String?
    let coordinate: Coordinate

    /// The coordinate is part of it: two branches of one chain can share a name and a short address, and the form's
    /// rows need distinct ids.
    var id: String { "\(title)|\(subtitle ?? "")|\(coordinate.latitude),\(coordinate.longitude)" }
}
