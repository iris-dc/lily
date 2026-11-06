import Foundation

/// One place the geocoder offers for a typed query: what to call it, where it is, and a line placing it ("Warsaw,
/// Poland"). Picking one fills the draft's name and spot at once.
nonisolated struct PlaceSuggestion: Identifiable, Equatable, Sendable {
    let title: String
    let subtitle: String?
    let coordinate: Coordinate

    var id: String { "\(title)|\(subtitle ?? "")" }
}
