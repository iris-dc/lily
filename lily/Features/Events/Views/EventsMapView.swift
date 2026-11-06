import MapKit
import SwiftUI

/// Map of the loaded events around the user's position. It opens on the user at the filter's radius whatever the pins
/// show, so an empty search still shows where the user is. Events on one spot stack into one pin with a count
/// (`EventMapStack`); selecting a pin shows a card per event, each opening its detail.
struct EventsMapView: View {
    let viewModel: EventListViewModel
    /// Room kept free to the right of the selected card, for a screen that floats a button over the map's bottom
    /// corner: the card sits beside the "+", never above it.
    let trailingInset: CGFloat
    @State private var position: MapCameraPosition
    /// Set once the camera has been put on the user, at init or when the position arrived, so later drift never moves it.
    @State private var hasCenteredOnUser: Bool
    @State private var selectedStackID: EventMapStack.ID?
    @Environment(\.motion) private var motion

    init(viewModel: EventListViewModel, trailingInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.trailingInset = trailingInset
        let userRegion = Self.userRegion(for: viewModel)
        _position = State(initialValue: userRegion.map { .region($0) } ?? .userLocation(fallback: .automatic))
        _hasCenteredOnUser = State(initialValue: userRegion != nil)
    }

    private var stacks: [EventMapStack] { EventMapStack.stacks(of: viewModel.visibleEvents) }

    private var selectedStack: EventMapStack? {
        stacks.first { $0.id == selectedStackID }
    }

    var body: some View {
        // The map bleeds under the floating tab bar; the card stays inside the safe area, beside the floating "+".
        ZStack(alignment: .bottomLeading) {
            map
            // Above the map for its whole life: a leaving view in a ZStack can drop behind its sibling, so the
            // cards slid out hidden under the opaque map and read as a cut.
            selectedStackCards
                .zIndex(1)
        }
        // Selecting and deselecting share one motion; under Reduce Motion the cards cut in place.
        .animation(motion.allowsMovement ? .snappy(duration: DesignTokens.Duration.fast) : nil, value: selectedStackID)
        // A pin the filter hides, or a stack a reload regrouped, must drop its selection too, or its card would pop out
        // unanimated and pop back already selected when the type returns.
        .onChange(of: stacks.map(\.id)) {
            if selectedStack == nil { selectedStackID = nil }
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
        Map(position: $position, selection: $selectedStackID) {
            UserAnnotation()
            ForEach(stacks) { stack in
                Annotation(stack.title, coordinate: stack.coordinate.clCoordinate, anchor: .bottom) {
                    EventMapPin(type: stack.events[0].type,
                                isSelected: stack.id == selectedStackID,
                                count: stack.events.count)
                        // MapKit selects a tapped pin only once a double-tap zoom is ruled out, about half a second
                        // late; the pin's own tap selects at once, and the map's later write of the same id is a no-op.
                        .onTapGesture { selectedStackID = stack.id }
                }
                .tag(stack.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton() }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsMap)
    }

    /// One card per event on the selected spot, each its own link, so both games at a venue can be opened.
    @ViewBuilder
    private var selectedStackCards: some View {
        if let selectedStack {
            EventMapCardList(stack: selectedStack, distanceText: viewModel.distanceText(for:))
                .padding(DesignTokens.Spacing.lg)
                .padding(.trailing, trailingInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Glass pin carrying the event type glyph; grows and turns red when selected, and wears the count of the events
/// stacked on its spot once there are several.
struct EventMapPin: View {
    let type: EventType
    let isSelected: Bool
    var count: Int = 1

    var body: some View {
        Image(systemName: type.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(LilyTheme.selectionLabelColor(isSelected: isSelected))
            .frame(width: DesignTokens.Layout.mapPinSize, height: DesignTokens.Layout.mapPinSize)
            .glassEffect(LilyTheme.selectionGlass(isSelected: isSelected), in: .circle)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(LilyTheme.selectionLabelColor(isSelected: true))
                        .padding(DesignTokens.Spacing.xs)
                        .background(Color.lilyAccent, in: .circle)
                        .offset(x: DesignTokens.Layout.mapPinBadgeInset, y: -DesignTokens.Layout.mapPinBadgeInset)
                }
            }
            .scaleEffect(isSelected ? DesignTokens.Layout.mapPinSelectedScale : 1)
            .lilyHoverable()
    }
}
