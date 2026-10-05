import SwiftUI

/// Which slide is on screen: one vertical bar per slide at the pager's trailing edge, the current one long and in the
/// accent, so the stack itself says "swipe up". Decorative for VoiceOver, which reads the slides themselves.
struct IntroPageIndicator: View {
    let slides: [IntroSlide]
    let current: IntroSlide

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(slides) { slide in
                Capsule()
                    .fill(fill(for: slide))
                    .frame(width: DesignTokens.Layout.introPageBarThickness, height: length(of: slide))
            }
        }
        .animation(.smooth(duration: DesignTokens.Duration.normal), value: current)
        .accessibilityHidden(true)
    }

    private func fill(for slide: IntroSlide) -> Color {
        slide == current ? .lilyAccent : .lilyInk.opacity(DesignTokens.Opacity.introPageBarInactive)
    }

    private func length(of slide: IntroSlide) -> CGFloat {
        slide == current ? DesignTokens.Layout.introPageBarActiveLength : DesignTokens.Layout.introPageBarLength
    }
}
