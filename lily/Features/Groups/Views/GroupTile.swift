import SwiftUI

/// One group in the Explore carousel: the mark, the name, a one-line caption and, for a group with a place, where it
/// plays with the distance, on a fixed-size glass tile so two rows of them line up.
struct GroupTile: View {
    let group: SportGroup
    var distance: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: group.name.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(group.caption(suffix: group.isMember ? AppBranding.Groups.joinedCaption : nil))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let place = group.placeCaption(distance: distance) {
                    Text(place)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(width: DesignTokens.Layout.groupTileWidth, height: DesignTokens.Layout.groupTileHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.card))
        .contentShape(.rect)
    }
}

#Preview {
    ContentScreen {
        GroupTile(group: MockGroupFixtures.make(now: .now)[0])
    }
}
