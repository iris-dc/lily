import SwiftUI

/// One line of a detail's People card: who hosts, who is going, the members. The role leading, then the first few
/// avatars, the name or count, and the chevron when the row opens the full list; a row with nowhere to go (a guest's
/// view) draws the facts alone. Generic over the destination so Core/UI stays free of the feature models.
struct PeopleSummaryRow<Destination: Hashable>: View {
    let title: String
    /// Whose circles to stack; empty draws none (a count without names, or a single named person in `detail`).
    var names: [String] = []
    /// The name or the count after the stack.
    var detail: String?
    /// An SF Symbol drawn before `detail` in its own secondary style (the deleted account's tombstone); `nil` for none.
    var detailMark: String?
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
            Text(title)
                .font(LilyTheme.Fonts.itemTitle)
            Spacer(minLength: DesignTokens.Spacing.sm)
            AvatarStack(names: names)
            if let detailMark {
                Image(systemName: detailMark)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
                VStack(spacing: 0) {
                    PeopleSummaryRow(title: "Hosting", detail: "Marta", destination: "people", identifier: "hosting")
                    Divider()
                    PeopleSummaryRow(title: "Going",
                                     names: ["Anna K", "Piotr N", "Jan W", "Ola Z"],
                                     detail: "9",
                                     destination: "people",
                                     identifier: "going")
                }
            }
            .padding()
        }
    }
}
