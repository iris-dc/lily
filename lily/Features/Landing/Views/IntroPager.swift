import SwiftUI

/// The intro as a vertical feed: one full-page slide per `IntroSlide`, snapping page by page the way short videos do,
/// each slide fading and shrinking a little as it leaves. At accessibility type sizes the pages give way to a plain
/// scroll of natural heights, so a tall caption is never clipped by its page.
struct IntroPager: View {
    let slides: [IntroSlide]
    let content: IntroContent
    let showsSwipeHint: Bool
    @Binding var visibleSlide: IntroSlide?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        // The page is the pager's own height, measured, never the container's: a `containerRelativeFrame` would
        // subtract the safe area that paging does not, and the pages would drift from the snap points.
        GeometryReader { geometry in
            feed(pageHeight: pages ? geometry.size.height : nil)
        }
    }

    @ViewBuilder
    private func feed(pageHeight: CGFloat?) -> some View {
        // Read here: the transition closure runs off the main actor and may not touch the view's environment.
        let reduceMotion = reduceMotion
        let feed = ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(slides) { slide in
                    IntroSlideView(slide: slide,
                                   content: content,
                                   showsSwipeHint: showsSwipeHint && slide == slides.first)
                        .frame(height: pageHeight)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : DesignTokens.Opacity.introSlideLeaving)
                                .scaleEffect(Self.leavingScale(phase, reduceMotion: reduceMotion))
                        }
                        .id(slide)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $visibleSlide)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityIdentifiers.introPager)
        if pageHeight != nil {
            feed.scrollTargetBehavior(.paging)
        } else {
            feed
        }
    }

    nonisolated private static func leavingScale(_ phase: ScrollTransitionPhase, reduceMotion: Bool) -> CGFloat {
        phase.isIdentity || reduceMotion ? 1 : DesignTokens.Layout.introSlideLeavingScale
    }
}
