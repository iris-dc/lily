import SwiftUI

/// One group in the Explore carousel: the mark, the name, a one-line caption and, for a group with a place, where it
/// plays with the distance, on a fixed-size glass tile so two rows of them line up.
struct GroupTile: View {
    let group: SportGroup
    var distance: String?
    /// In a wrapping grid the tile takes its cell's width; in the carousel it keeps the fixed one so the rows line up.
    var fillsWidth = false

    var body: some View {
        TileContent(avatar: AvatarCircle(initials: group.name.initials,
                                         size: DesignTokens.Layout.avatarMedium,
                                         tint: .secondary),
                    title: group.name,
                    lines: lines)
            .glassTile(fixedWidth: DesignTokens.Layout.groupTileWidth,
                       height: DesignTokens.Layout.groupTileHeight,
                       fillsWidth: fillsWidth)
    }

    private var lines: [String] {
        [group.caption(suffix: group.isMember ? AppBranding.Groups.joinedCaption : nil),
         group.placeCaption(distance: distance)].compactMap { $0 }
    }
}

#Preview {
    ContentScreen {
        GroupTile(group: MockGroupFixtures.make(now: .now)[0])
    }
}
