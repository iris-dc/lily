import SwiftUI

/// One page of the intro: a framed miniature of a real screen above, the caption (two headline lines, a message, the
/// hint row) at the bottom, so every slide reads like a post in a feed and the captions sit at one height from slide
/// to slide. The miniature fills whatever the page leaves over; at accessibility type sizes, where the pager has no
/// page height, it takes a fixed one.
struct IntroSlideView: View {
    let slide: IntroSlide
    let content: IntroContent
    let showsSwipeHint: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The caption is laid out first; the frame takes what the page leaves, or it would push the caption off.
            // The list crops at its bottom; the detail and the room at their top, so a tall caption (French) never
            // takes the Join or the composer, which are the point.
            IntroScreenFrame(fadesBottom: slide == .discover, alignment: slide == .discover ? .top : .bottom) { screen }
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .frame(height: typeSize.isAccessibilitySize ? DesignTokens.Layout.introScreenAccessibilityHeight : nil)
                .layoutPriority(-1)
                .padding(.top, DesignTokens.Spacing.lg)
            LandingHeadline(lines: slide.headline, subtitle: slide.message)
                .padding(.top, DesignTokens.Spacing.xl)
            SwipeHint(isShown: showsSwipeHint)
                .padding(.top, DesignTokens.Spacing.lg)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.bottom, DesignTokens.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.introSlide(slide))
    }

    @ViewBuilder
    private var screen: some View {
        switch slide {
        case .discover:
            IntroExploreScreen(events: content.events)
        case .join:
            if let event = content.joinEvent {
                IntroDetailScreen(event: event)
            }
        case .create:
            IntroChatScreen(eventTitle: content.joinEvent?.title ?? "")
        }
    }
}

/// "Swipe up" with a bouncing chevron; present on every slide at `introHintRowHeight` (scaled with the footnote), visible
/// on the first until the user has swiped, so the row never shifts a caption.
private struct SwipeHint: View {
    let isShown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var rowHeight = DesignTokens.Layout.introHintRowHeight

    var body: some View {
        Label(AppBranding.Intro.swipeHint, systemImage: DesignTokens.Symbols.swipeUp)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .symbolEffect(.bounce.up,
                          options: .repeat(.periodic(delay: DesignTokens.Duration.introHintBouncePause)),
                          isActive: isShown && !reduceMotion)
            .frame(height: rowHeight)
            .opacity(isShown ? 1 : 0)
            .animation(.easeOut(duration: DesignTokens.Duration.normal), value: isShown)
            .accessibilityHidden(!isShown)
    }
}

#Preview("Slide") {
    ZStack {
        AuroraBackground(intensity: DesignTokens.Aurora.landingIntensity)
        IntroSlideView(slide: .join, content: IntroContent(events: IntroFixtures.events(now: .now)), showsSwipeHint: false)
    }
}
