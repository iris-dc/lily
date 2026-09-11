import MapKit
import SwiftUI

/// Map of the loaded events with the user's position. Selecting a pin shows a card that opens the detail.
struct EventsMapView: View {
    let viewModel: EventListViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedEventID: SportEvent.ID?

    private var selectedEvent: SportEvent? {
        viewModel.visibleEvents.first { $0.id == selectedEventID }
    }

    var body: some View {
        // The map bleeds under the floating tab bar; the card stays inside the safe area, above it.
        ZStack(alignment: .bottom) {
            map
            selectedEventCard
        }
        .animation(.spring(duration: DesignTokens.Duration.normal), value: selectedEventID)
        // A pin the filter hides must drop its selection too, or its card would pop out unanimated and pop back
        // already selected when the type returns.
        .onChange(of: viewModel.filter) {
            if selectedEvent == nil { selectedEventID = nil }
        }
    }

    private var map: some View {
        Map(position: $position, selection: $selectedEventID) {
            UserAnnotation()
            ForEach(viewModel.visibleEvents) { event in
                Annotation(event.title, coordinate: event.location.coordinate.clCoordinate, anchor: .bottom) {
                    EventMapPin(type: event.type, isSelected: event.id == selectedEventID)
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

/// Glass pin carrying the event type glyph; grows and turns red when selected.
struct EventMapPin: View {
    let type: EventType
    let isSelected: Bool

    var body: some View {
        Image(systemName: type.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(LilyTheme.selectionLabelColor(isSelected: isSelected))
            .frame(width: DesignTokens.Layout.mapPinSize, height: DesignTokens.Layout.mapPinSize)
            .glassEffect(LilyTheme.selectionGlass(isSelected: isSelected), in: .circle)
            .scaleEffect(isSelected ? DesignTokens.Layout.mapPinSelectedScale : 1)
    }
}
