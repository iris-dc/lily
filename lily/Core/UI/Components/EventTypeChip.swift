import SwiftUI

/// Badge naming an event's type on cards and the detail screen: the sport's white glyph in a small filled mark, the name
/// in ink, on glass tinted maroon so the badge belongs to the app's red.
struct EventTypeChip: View {
    let type: EventType
    @ScaledMetric(relativeTo: .footnote) private var markSize = DesignTokens.Layout.chipMarkSize

    var body: some View {
        Label {
            Text(type.displayName)
                .foregroundStyle(Color.lilyInk)
        } icon: {
            Image(systemName: type.symbolName)
                .font(LilyTheme.Fonts.sportGlyph(size: markSize))
                .foregroundStyle(.white)
                .frame(width: markSize, height: markSize)
                .sportFill(in: .circle)
                .accessibilityHidden(true)
        }
        .lilyChip(.regular.tint(Color.lilyAccentDeep.opacity(DesignTokens.Opacity.sportGlassTint)))
    }
}
