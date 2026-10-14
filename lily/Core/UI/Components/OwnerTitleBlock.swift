import SwiftUI

/// The screen title with who owns it underneath (the event's host, the tournament's organiser), a link to that
/// person's profile when the caller may open it (`destination` set) and the line alone otherwise. Generic over the
/// destination so Core/UI stays free of the People model; both callers pass a `UserProfileDestination`.
struct OwnerTitleBlock<Destination: Hashable>: View {
    let title: String
    let subtitle: String
    let destination: Destination?
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ScreenTitle(text: title)
            if let destination {
                NavigationLink(value: destination) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        subtitleLine
                        Image(systemName: DesignTokens.Symbols.chevron)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
            } else {
                subtitleLine
            }
        }
    }

    private var subtitleLine: ScreenSubtitle { ScreenSubtitle(text: subtitle) }
}

#Preview {
    ContentScreen {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            OwnerTitleBlock(title: "Sunset 5-a-side", subtitle: "Hosted by Marta", destination: "marta", identifier: "")
            OwnerTitleBlock<String>(title: "Sunset 5-a-side", subtitle: "Hosted by Marta", destination: nil, identifier: "")
        }
        .padding()
    }
}
