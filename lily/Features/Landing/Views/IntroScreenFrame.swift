import SwiftUI

/// A phone-shaped frame around a miniature of a real screen: a translucent fill with a thin stroke in the screen's
/// corner radius, the content cropped at `alignment` (top for a list, bottom for a detail and a room, whose Join and
/// composer must survive a short phone or a tall caption), fading out towards the bottom where the screen goes on below (a
/// list), not where its last control is the point (a detail's Join, a room's composer). A bottom-aligned screen taller
/// than the frame (a short phone, a four-line caption) fades out at the top instead, where it is cropped, so the cut
/// never runs through a chip or a title. The miniature is a picture: its type size is fixed, it takes no taps and
/// VoiceOver reads the caption.
struct IntroScreenFrame<Content: View>: View {
    var fadesBottom = true
    var alignment: Alignment = .top
    /// The phone's width; a regular width shows a wider one beside the caption.
    var width: CGFloat = DesignTokens.Layout.introScreenWidth
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0
    @State private var frameHeight: CGFloat = 0

    var body: some View {
        content()
            .dynamicTypeSize(DesignTokens.Layout.introScreenTypeSize)
            .padding(DesignTokens.Spacing.lg)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
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
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { frameHeight = $0 }
            .frame(width: width)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Whether the content is cropped at the top: bottom-aligned and taller than the measured frame.
    private var fadesTop: Bool {
        alignment == .bottom && frameHeight > 0 && contentHeight > frameHeight + DesignTokens.Layout.introScreenOverflowTolerance
    }

    private var fade: some View {
        let bottom = fadesBottom ? DesignTokens.Layout.introScreenFadeFraction : 0
        let top = fadesTop ? min(DesignTokens.Layout.introScreenTopFadeLength / frameHeight, bottom == 0 ? 1 : 1 - bottom) : 0
        let stops: [Gradient.Stop] = [
            .init(color: fadesTop ? .clear : .black, location: 0),
            .init(color: .black, location: top),
            .init(color: .black, location: 1 - bottom),
            .init(color: fadesBottom ? .clear : .black, location: 1),
        ]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}
