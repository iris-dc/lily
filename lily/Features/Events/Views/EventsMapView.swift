import MapKit
import SwiftUI

/// Map of the loaded events around the user's position. It opens on the user at the filter's radius whatever the pins
/// show, so an empty search still shows where the user is. Selecting a pin shows a card that opens the detail.
struct EventsMapView: View {
    let viewModel: EventListViewModel
    /// Extra room under the selected card, for a screen that floats a button over the map's bottom corner.
    let bottomInset: CGFloat
    @State private var position: MapCameraPosition
    /// Set once the camera has been put on the user, at init or when the position arrived, so later drift never moves it.
    @State private var hasCenteredOnUser: Bool
    @State private var selectedEventID: SportEvent.ID?

    init(viewModel: EventListViewModel, bottomInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.bottomInset = bottomInset
        let userRegion = Self.userRegion(for: viewModel)
        _position = State(initialValue: userRegion.map { .region($0) } ?? .userLocation(fallback: .automatic))
        _hasCenteredOnUser = State(initialValue: userRegion != nil)
    }

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
        // A position that arrives after the map opened moves the camera to the user once, unless they already panned.
        .onChange(of: viewModel.userLocation) {
            guard !hasCenteredOnUser, !position.positionedByUser, let region = Self.userRegion(for: viewModel) else { return }
            position = .region(region)
            hasCenteredOnUser = true
        }
    }

    /// On the user at the filter's radius; `nil` while the app has no position, when the map's own fix or its content
    /// frames the start.
    private static func userRegion(for viewModel: EventListViewModel) -> MKCoordinateRegion? {
        MapFraming.initialRegion(userLocation: viewModel.userLocation, radiusMeters: viewModel.filter.maxDistanceMeters)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsMap)
    }

    @ViewBuilder
    private var selectedEventCard: some View {
        if let selectedEvent {
            NavigationLink(value: selectedEvent) {
                EventPreviewCard(event: selectedEvent, detail: viewModel.distanceText(for: selectedEvent))
                    .frame(maxWidth: DesignTokens.Layout.mapSelectedCardWidth)
            }
            .buttonStyle(.plain)
            .lilyHoverable()
            .padding(DesignTokens.Spacing.lg)
            .padding(.bottom, bottomInset)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier(AccessibilityIdentifiers.mapSelectedCard)
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
            .lilyHoverable()
    }
}
