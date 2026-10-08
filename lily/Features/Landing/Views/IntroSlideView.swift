import SwiftUI

/// One page of the intro: a framed miniature of a real screen and the caption (two headline lines, a message, the hint
/// row). On a compact width the miniature sits above the caption, which stays at the bottom, so every slide reads like
/// a post in a feed and the captions sit at one height from slide to slide; the miniature fills whatever the page
/// leaves over. On a regular width the miniature stands beside the caption, both vertically centred, the composition
/// capped at a readable width. At accessibility type sizes, where the pager has no page height, the miniature takes a
/// fixed one.
struct IntroSlideView: View {
    let slide: IntroSlide
    let content: IntroContent
    let showsSwipeHint: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias Layout = DesignTokens.Layout

    var body: some View {
        Group {
            if sizeClass == .regular {
                sideBySide
            } else {
                stacked
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.bottom, DesignTokens.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.introSlide(slide))
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The caption is laid out first; the frame takes what the page leaves, or it would push the caption off.
            // The list crops at its bottom; the detail and the room at their top, so a tall caption (French) never
            // takes the Join or the composer, which are the point.
            frame(width: Layout.introScreenWidth)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .frame(height: accessibilityHeight)
                .layoutPriority(-1)
                .padding(.top, DesignTokens.Spacing.lg)
            LandingHeadline(lines: slide.headline, subtitle: slide.message)
                .padding(.top, DesignTokens.Spacing.xl)
            SwipeHint(isShown: showsSwipeHint)
                .padding(.top, DesignTokens.Spacing.lg)
        }
    }

    /// The miniature keeps a phone's proportions (its width times `introScreenWideAspect` at most) rather than the whole
    /// page's height, so on a tall portrait page it does not turn into a strip.
    private var sideBySide: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xxl) {
            frame(width: Layout.introScreenWideWidth)
                .frame(minHeight: 0, maxHeight: Layout.introScreenWideWidth * Layout.introScreenWideAspect)
                .frame(height: accessibilityHeight)
                .layoutPriority(-1)
            VStack(alignment: .leading, spacing: 0) {
                LandingHeadline(lines: slide.headline, subtitle: slide.message)
                SwipeHint(isShown: showsSwipeHint)
                    .padding(.top, DesignTokens.Spacing.lg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
        .frame(maxHeight: .infinity)
        .readableColumn(maxWidth: Layout.introCompositionMaxWidth)
    }

    private var accessibilityHeight: CGFloat? {
        typeSize.isAccessibilitySize ? Layout.introScreenAccessibilityHeight : nil
    }

    private func frame(width: CGFloat) -> some View {
        IntroScreenFrame(fadesBottom: slide == .discover, alignment: slide == .discover ? .top : .bottom, width: width) {
            screen
        }
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
