import SwiftUI

/// The form row that opens `LocationPickerView` and reads the chosen spot back: shared by the event, tournament and
/// group forms so the three say "Set the spot on the map", "Not set" and "Spot set" the same way; the exact
/// coordinates stay on the picker screen. The caller sets the identifier.
struct PlacePickerRow: View {
    @Binding var coordinate: Coordinate?

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        NavigationLink {
            LocationPickerView(coordinate: $coordinate)
        } label: {
            LabeledContent(Copy.pickOnMap) {
                Text(coordinate == nil ? Copy.spotNotSet : Copy.spotSet)
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
