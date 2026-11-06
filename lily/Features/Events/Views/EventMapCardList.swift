import SwiftUI

/// The cards of the selected map stack, one link per event, as tall as its cards up to the cap and scrolling the rest.
/// One event is its card alone on its own glass. Several sit in one glass panel headed by the place and the count; an
/// edge with more beyond it fades, and while whole cards wait below, a "+2 more" pill says so and scrolls to the end
/// when tapped.
struct EventMapCardList: View {
    let stack: EventMapStack
    let distanceText: (SportEvent) -> String?
    /// The measured card-list height, clamping the scroll view to its content up to the cap.
    @State private var cardListHeight: CGFloat = 0
    /// Where the list is scrolled; back at the top for every selection, since a pin tapped straight after another keeps
    /// the same scroll view and would open part-way down.
    @State private var cardScroll = ScrollPosition(edge: .top)
    /// Whether content runs past either edge, read off the scroll geometry, so it holds at any type size.
    @State private var edges = MapCardListEdges.none
    /// The cards at least half in view, as the scroll view reports them; what the pill counts past.
    @State private var visibleCardIDs: [SportEvent.ID] = []
    @Environment(\.motion) private var motion

    private var isPanel: Bool { stack.events.count > 1 }

    private var animation: Animation? {
        motion.allowsMovement ? .snappy(duration: DesignTokens.Duration.fast) : nil
    }

    var body: some View {
        if isPanel {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                header
                cards
            }
            .padding(DesignTokens.Spacing.sm)
            .frame(maxWidth: DesignTokens.Layout.mapSelectedCardWidth)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.card))
        } else {
            cards
                .frame(maxWidth: DesignTokens.Layout.mapSelectedCardWidth)
        }
    }

    /// The place and how many events it holds: the count is there before the list shows that it scrolls.
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: DesignTokens.Symbols.pickedLocation)
                .foregroundStyle(Color.lilyAccent)
                .accessibilityHidden(true)
            Text(stack.events[0].locationName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.lilyInk)
                .lineLimit(1)
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(AppBranding.Events.eventsHere(stack.events.count))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .font(LilyTheme.Fonts.caption)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.top, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var cards: some View {
        ScrollView {
            // The identifier stays on the plain stack, where it stamps the card links (`app.buttons`); set on the
            // scroll view it reaches no element.
            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(stack.events) { event in
                    NavigationLink(value: event) {
                        EventPreviewCard(event: event, detail: distanceText(event), surface: isPanel ? .inset : .glass)
                    }
                    // Not `.plain`: a plain NavigationLink keeps its pressed dim after the push, so the card came back
                    // from the detail still looking held down. This style's press state always lets go.
                    .buttonStyle(MapCardButtonStyle(motion: motion))
                    .lilyHoverable()
                }
            }
            .scrollTargetLayout()
            .accessibilityIdentifier(AccessibilityIdentifiers.mapSelectedCard)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { cardListHeight = $0 })
        }
        // A `fixedSize` would ignore the cap and overflow under the "+"; the measured height keeps the hit area exactly
        // the visible cards'.
        .frame(height: min(max(cardListHeight, 1), DesignTokens.Layout.mapCardListMaxHeight))
        .scrollPosition($cardScroll)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: MapCardListEdges.self, of: Self.edges(of:), action: { edges = $1 })
        .onScrollTargetVisibilityChange(idType: SportEvent.ID.self,
                                        threshold: DesignTokens.Layout.mapCardVisibleShare) { visibleCardIDs = $0 }
        .mask { fadeMask }
        .overlay(alignment: .bottom) { morePill }
        .animation(animation, value: edges)
        .onChange(of: stack.id) { cardScroll.scrollTo(edge: .top) }
    }

    nonisolated private static func edges(of geometry: ScrollGeometry) -> MapCardListEdges {
        MapCardListEdges(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                         contentHeight: geometry.contentSize.height,
                         containerHeight: geometry.containerSize.height)
    }

    /// Opaque between two fades, each dissolving the cut card into the panel only while more wait beyond its edge.
    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [edges.hasMoreAbove ? .clear : .black, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: DesignTokens.Layout.mapCardListFade)
            Color.black
            LinearGradient(colors: [.black, edges.hasMoreBelow ? .clear : .black], startPoint: .top, endPoint: .bottom)
                .frame(height: DesignTokens.Layout.mapCardListFade)
        }
    }

    /// Whole cards still below the last one in view; the pill shows only in the panel and only while there are some.
    private var cardsBelow: Int {
        guard isPanel, edges.hasMoreBelow else { return 0 }
        return MapCardListEdges.cardsBelow(in: stack.events.map(\.id), visible: visibleCardIDs)
    }

    @ViewBuilder private var morePill: some View {
        if cardsBelow > 0 {
            Button {
                withAnimation(animation) { cardScroll.scrollTo(edge: .bottom) }
            } label: {
                Label(AppBranding.Events.moreBelow(cardsBelow), systemImage: DesignTokens.Symbols.moreBelow)
                    .labelStyle(.titleThenIcon)
                    .font(LilyTheme.Fonts.caption.weight(.semibold))
            }
            .lilyProminentButton(sizing: .fitted, controlSize: .regular)
            .padding(.bottom, DesignTokens.Spacing.sm)
            .transition(.opacity.combined(with: .scale(scale: DesignTokens.Layout.mapMorePillEntryScale)))
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
