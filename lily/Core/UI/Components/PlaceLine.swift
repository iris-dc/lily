import SwiftUI

/// A place and, when the user's position is known, the distance to it: "Riverside Pitch 2 · 1,6 km" with the pin and
/// the arrow glyphs. The event and tournament cards draw it at the subheadline size, the group card and header as a
/// caption.
struct PlaceLine: View {
    let name: String
    var distance: String?
    var font: Font = .subheadline

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Label(name, systemImage: DesignTokens.Symbols.location)
            if let distance {
                Text(AppBranding.Events.separatorGlyph)
                Label(distance, systemImage: DesignTokens.Symbols.distance)
            }
        }
        .font(font)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentScreen {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            PlaceLine(name: "Riverside Pitch 2", distance: "1,6 km")
            PlaceLine(name: "Görlitzer Park", font: LilyTheme.Fonts.caption)
        }
        .padding()
    }
}
