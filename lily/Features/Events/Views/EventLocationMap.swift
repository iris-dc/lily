import MapKit
import SwiftUI

/// Where the event is, on the detail: the spot pinned at neighbourhood scale, framed like a card. Not interactive;
/// the pin says where, the facts card above says what it is called.
struct EventLocationMap: View {
    let event: SportEvent

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            Annotation(event.locationName, coordinate: event.location.coordinate.clCoordinate, anchor: .bottom) {
                EventMapPin(type: event.type, isSelected: true)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: DesignTokens.Layout.detailMapHeight)
        .clipShape(.rect(cornerRadius: DesignTokens.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.eventDetailMap)
    }

    private var region: MKCoordinateRegion {
        let span = AppConfig.Location.pickerRegionMeters
        return MKCoordinateRegion(center: event.location.coordinate.clCoordinate,
                                  latitudinalMeters: span,
                                  longitudinalMeters: span)
    }
}

#Preview {
    ContentScreen {
        EventLocationMap(event: MockEventFixtures.make(now: .now, count: 1)[0]).padding()
    }
}
