import SwiftUI

/// A public group on Discover: visibility and type chips, the name, two lines of description, where it plays with the
/// distance when known, the member count, and "Joined" when the caller is in.
struct GroupCard: View {
    let group: SportGroup
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Label(group.visibility.displayName, systemImage: group.visibility.symbolName)
                        .lilyChip(.regular)
                        .fixedSize()
                    if let type = group.type {
                        EventTypeChip(type: type).fixedSize()
                    }
                    Spacer()
                    if group.isMember {
                        Text(AppBranding.Groups.joinedCaption)
                            .font(LilyTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(group.name).font(LilyTheme.Fonts.cardTitle)
                    if let description = group.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(DesignTokens.Layout.cardDescriptionLines)
                    }
                }
                if let location = group.location {
                    PlaceLine(name: location.name, distance: distance, font: LilyTheme.Fonts.caption)
                }
                Label(AppBranding.Groups.members(group.memberCount), systemImage: DesignTokens.Symbols.groups)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentScreen {
        GroupCard(group: MockGroupFixtures.make(now: .now)[0], distance: "1,7 km").padding()
    }
}
