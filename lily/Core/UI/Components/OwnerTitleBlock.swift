import SwiftUI

/// The screen title with who owns it underneath (the event's host, the tournament's organiser), as a link to their
/// profile when `destination` is set and a plain line otherwise, with an optional glyph before the line (the deleted
/// account's tombstone mark). Generic over the destination so Core/UI stays free of the People model.
struct OwnerTitleBlock<Destination: Hashable>: View {
    let title: String
    let subtitle: String
    let destination: Destination?
    /// An SF Symbol drawn before the subtitle in its own secondary style; `nil` for none.
    var subtitleMark: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ScreenTitle(text: title)
            if let destination {
                ChevronLink(value: destination) { subtitleLine }
            } else {
                subtitleLine
            }
        }
    }

    @ViewBuilder private var subtitleLine: some View {
        if let subtitleMark {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: subtitleMark)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScreenSubtitle(text: subtitle)
            }
        } else {
            ScreenSubtitle(text: subtitle)
        }
    }
}

#Preview {
    ContentScreen {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            OwnerTitleBlock(title: "Sunset 5-a-side", subtitle: "Hosted by Marta", destination: "marta")
            OwnerTitleBlock<String>(title: "Sunset 5-a-side", subtitle: "Hosted by Marta", destination: nil)
        }
        .padding()
    }
}
