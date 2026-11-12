import SwiftUI

/// The form row that opens `LocationPickerView` and reads the chosen spot back: shared by the event, tournament and
/// group forms so the three say "Set the spot on the map", "Not set" and "Spot set" the same way; the exact
/// coordinates stay on the picker screen. The caller sets the identifier.
struct PlacePickerRow: View {
    @Binding var coordinate: Coordinate?
    /// Whether the draft's place really was chosen (a tapped suggestion or a set spot): until then the label reads
    /// as the explicit alternative and the value stays "Not set", a proposed spot never counting as a choice
    /// (round 5). A form without the choice rule (the match schedule) keeps the default.
    var placeChosen = true

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        NavigationLink {
            LocationPickerView(coordinate: $coordinate)
        } label: {
            LabeledContent(placeChosen ? Copy.pickOnMap : Copy.orPickOnMap) {
                Text(placeChosen && coordinate != nil ? Copy.spotSet : Copy.spotNotSet)
            }
        }
    }
}

#Preview {
    @Previewable @State var coordinate: Coordinate? = AppConfig.Location.mockCenter
    NavigationStack {
        Form {
            PlacePickerRow(coordinate: $coordinate)
        }
    }
}
