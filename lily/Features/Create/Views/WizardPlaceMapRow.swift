import SwiftUI

/// The place pages' pick-on-map row, shared by the three kinds: a glass navigation row pushing the map picker on the
/// wizard's stack as the kind's map path element. Until the place really is chosen the label reads as the explicit
/// alternative ("Or set the spot on the map") and the value stays "Not set": a proposed spot never counts as a
/// choice (round 5).
struct WizardPlaceMapRow: View {
    /// The kind's map path element (`.eventMap`, `.groupMap`, `.tournamentMap`).
    let mapStep: CreationStep
    let identifier: String
    let placeChosen: Bool
    let hasSpot: Bool

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        GlassNavigationRow(value: mapStep, identifier: identifier) {
            LabeledContent(placeChosen ? Copy.pickOnMap : Copy.orPickOnMap) {
                Text(placeChosen && hasSpot ? Copy.spotSet : Copy.spotNotSet)
            }
        }
    }
}
