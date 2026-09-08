import MapKit
import SwiftUI

/// Map of the loaded events with the user's position. Selecting a pin shows a card that opens the detail.
struct EventsMapView: View {
    let viewModel: EventListViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedEventID: SportEvent.ID?

    private var selectedEvent: SportEvent? {
        viewModel.filteredEvents.first { $0.id == selectedEventID }
    }

    var body: some View {
        // The map bleeds under the floating tab bar; the card stays inside the safe area, above it.
        ZStack(alignment: .bottom) {
            map
            selectedEventCard
        }
        .animation(.spring(duration: DesignTokens.Duration.normal), value: selectedEventID)
    }

    private var map: some View {
        Map(position: $position, selection: $selectedEventID) {
            UserAnnotation()
            ForEach(viewModel.filteredEvents) { event in
                Annotation(event.title, coordinate: event.location.coordinate.clCoordinate, anchor: .bottom) {
                    EventMapPin(sport: event.sport, isSelected: event.id == selectedEventID)
                }
                .tag(event.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton() }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("events-map")
    }

    @ViewBuilder
    private var selectedEventCard: some View {
        if let selectedEvent {
            NavigationLink(value: selectedEvent) {
                EventPreviewCard(event: selectedEvent, detail: viewModel.distanceText(for: selectedEvent))
                    .frame(maxWidth: DesignTokens.Layout.mapSelectedCardWidth)
            }
            .buttonStyle(.plain)
            .padding(DesignTokens.Spacing.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("map-selected-card")
        }
    }
}

/// Glass pin carrying the sport glyph; grows and turns red when selected.
struct EventMapPin: View {
    let sport: SportType
    let isSelected: Bool

    var body: some View {
        Image(systemName: sport.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.lilyInk)
            .frame(width: DesignTokens.Layout.mapPinSize, height: DesignTokens.Layout.mapPinSize)
            .glassEffect(isSelected ? .regular.tint(Color.lilyAccent) : .regular, in: .circle)
            .scaleEffect(isSelected ? 1.15 : 1)
    }
}

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
