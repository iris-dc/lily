import SwiftUI

/// The text column of a row or tile led by a mark: the name on one line in `itemTitle`, then one caption line per entry.
struct CaptionedTitle<Title: View>: View {
    let lines: [String]
    @ViewBuilder let title: () -> Title

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            title()
                .font(LilyTheme.Fonts.itemTitle)
                .lineLimit(1)
            ForEach(Array(lines.enumerated()), id: \.offset) { line in
                Text(line.element)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
