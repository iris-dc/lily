import MapKit
import SwiftUI

/// Where the event is, on the detail: the spot pinned at neighbourhood scale, framed like a card. The map itself is
/// not interactive; tapping it hands the spot to Apple Maps, named after the place, for directions and a look around.
struct EventLocationMap: View {
    let event: SportEvent

    var body: some View {
        Button(action: openInMaps) {
            Map(initialPosition: .region(region), interactionModes: []) {
                Annotation(event.locationName, coordinate: event.location.coordinate.clCoordinate, anchor: .bottom) {
                    EventMapPin(type: event.type, isSelected: true)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            // initialPosition is read once per identity: an edit that moves the spot must rebuild the camera.
            .id(event.location.coordinate)
            .frame(height: DesignTokens.Layout.detailMapHeight)
            .overlay(alignment: .bottomTrailing) {
                Label(AppBranding.Events.openInMaps, systemImage: DesignTokens.Symbols.distance)
                    .lilyChip(.regular)
                    .padding(DesignTokens.Spacing.sm)
            }
            .clipShape(.rect(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.eventDetailMap)
        .accessibilityLabel(Text(AppBranding.Events.openInMaps))
    }

    private var region: MKCoordinateRegion {
        let span = AppConfig.Location.pickerRegionMeters
        return MKCoordinateRegion(center: event.location.coordinate.clCoordinate,
                                  latitudinalMeters: span,
                                  longitudinalMeters: span)
    }

    private func openInMaps() {
        let coordinate = event.location.coordinate
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                             address: nil)
        item.name = event.locationName
        item.openInMaps()
    }
}

#Preview {
    ContentScreen {
        EventLocationMap(event: MockEventFixtures.make(now: .now, count: 1)[0]).padding()
    }
}
