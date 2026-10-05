import SwiftUI

/// A phone-shaped frame around a miniature of a real screen: a translucent fill with a thin stroke in the screen's
/// corner radius, the content cropped at `alignment` (top for a list, bottom for a detail and a room, whose Join and
/// composer must survive a short phone or a tall caption), fading out towards the bottom where the screen goes on below (a
/// list), not where its last control is the point (a detail's Join, a room's composer). The miniature is a picture:
/// its type size is fixed, it takes no taps and VoiceOver reads the caption.
struct IntroScreenFrame<Content: View>: View {
    var fadesBottom = true
    var alignment: Alignment = .top
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .dynamicTypeSize(DesignTokens.Layout.introScreenTypeSize)
            .padding(DesignTokens.Spacing.lg)
            // `minHeight: 0` matters: without it a flexible frame grows to its content and the crop never happens.
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: alignment)
            .background(Color.lilySurface.opacity(DesignTokens.Opacity.introScreenFill))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.screen)
                    .strokeBorder(Color.lilyInk.opacity(DesignTokens.Opacity.introScreenStroke),
                                  lineWidth: DesignTokens.Layout.introScreenStrokeWidth)
            }
            .clipShape(.rect(cornerRadius: DesignTokens.Radius.screen))
            .mask(fade)
            .frame(width: DesignTokens.Layout.introScreenWidth)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var fade: some View {
        let fraction = fadesBottom ? DesignTokens.Layout.introScreenFadeFraction : 0
        let stops: [Gradient.Stop] = [
            .init(color: .black, location: 0),
            .init(color: .black, location: 1 - fraction),
            .init(color: fadesBottom ? .clear : .black, location: 1),
        ]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}
