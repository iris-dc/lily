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
    /// The selected stack's measured card-list height, clamping the scroll view to its content up to the cap.
    @State private var cardListHeight: CGFloat = 0
    /// Where the card list is scrolled; back at the top for every selection, since a pin tapped straight after
    /// another keeps the same scroll view and would open part-way down.
    @State private var cardScroll = ScrollPosition(edge: .top)
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
        // A pin the filter hides must drop its selection too, or its card would pop out unanimated and pop back
        // already selected when the type returns.
        .onChange(of: selectedStackID) { cardScroll.scrollTo(edge: .top) }
        .onChange(of: viewModel.filter) {
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
            ScrollView {
                // The identifier stays on the plain stack: there it stamps the card links (`app.buttons`), as it did
                // before the scroll view, which swallows an identifier set on itself.
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(selectedStack.events) { event in
                        NavigationLink(value: event) {
                            EventPreviewCard(event: event, detail: viewModel.distanceText(for: event))
                        }
                        // Not `.plain`: a plain NavigationLink keeps its pressed dim after the push, so the card
                        // came back from the detail still looking held down. This style's press state always lets go.
                        .buttonStyle(MapCardButtonStyle(motion: motion))
                        .lilyHoverable()
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.mapSelectedCard)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { cardListHeight = $0 })
            }
            // As tall as its cards up to the cap, about five, and scrolls the rest. A `fixedSize` would ignore the
            // cap and overflow under the "+"; the measured height keeps the hit area exactly the visible cards'.
            .frame(maxWidth: DesignTokens.Layout.mapSelectedCardWidth)
            .frame(height: min(max(cardListHeight, 1), DesignTokens.Layout.mapCardListMaxHeight))
            .scrollPosition($cardScroll)
            .scrollBounceBehavior(.basedOnSize)
            .padding(DesignTokens.Spacing.lg)
            .padding(.trailing, trailingInset)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The selected card's press feedback: dimmed and slightly shrunk exactly while the finger holds it, animated fast
/// both ways so the release visibly lets go. Under Reduce Motion the dim stays (a fade in place) and the shrink goes.
private struct MapCardButtonStyle: ButtonStyle {
    let motion: MotionPreference

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? DesignTokens.Opacity.pressedCard : 1)
            .scaleEffect(configuration.isPressed && motion.allowsMovement ? DesignTokens.Layout.pressedCardScale : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.fast), value: configuration.isPressed)
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
