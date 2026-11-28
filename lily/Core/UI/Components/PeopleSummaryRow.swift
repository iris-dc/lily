import SwiftUI

/// The one line of a detail's People card: who runs it and how many are in ("Hosted by Marta" over "5 going"), the
/// first few avatars, and the chevron when the row opens the full list; a row with nowhere to go (a guest's view)
/// draws the facts alone. Generic over the destination so Core/UI stays free of the feature models.
struct PeopleSummaryRow<Destination: Hashable>: View {
    let title: String
    /// The count line under the title ("5 going", "34 members", "4 of 8 teams").
    var caption: String?
    /// Whose circles to stack; empty draws none (a guest's count without names).
    var names: [String] = []
    /// An SF Symbol drawn before the title in its own secondary style (the deleted account's tombstone); `nil` for none.
    var titleMark: String?
    /// Where the full list is; `nil` for a caller who may not open it.
    var destination: Destination?
    let identifier: String

    var body: some View {
        if let destination {
            NavigationLink(value: destination) { content(linked: true) }
                .buttonStyle(.plain)
                .lilyHoverable()
                .accessibilityIdentifier(identifier)
        } else {
            content(linked: false)
                .accessibilityIdentifier(identifier)
        }
    }

    private func content(linked: Bool) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let titleMark {
                        Image(systemName: titleMark)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(LilyTheme.Fonts.itemTitle)
                }
                if let caption {
                    Text(caption)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            AvatarStack(names: names)
            if linked {
                Image(systemName: DesignTokens.Symbols.chevron)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: DesignTokens.Layout.controlHeight)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ContentScreen {
            GlassCard {
                PeopleSummaryRow(title: "Hosted by Marta",
                                 caption: "5 going",
                                 names: ["Marta L", "Anna K", "Piotr N", "Jan W"],
                                 destination: "people",
                                 identifier: "people-row")
            }
            .padding()
        }
    }
}
