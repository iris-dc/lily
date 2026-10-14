import SwiftUI

/// Top of the group detail: chips for visibility and type, the name, who runs it and how many are in, where it plays
/// (with the distance when the position is known), the description.
struct GroupHeader: View {
    let group: SportGroup
    var distance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                VisibilityChip(visibility: group.visibility)
                if let type = group.type {
                    EventTypeChip(type: type)
                }
            }
            ScreenTitle(text: group.name, subtitle: subtitle)
            if let location = group.location {
                PlaceLine(name: location.name, distance: distance, font: LilyTheme.Fonts.caption)
            }
            if let description = group.description {
                Text(description).font(.body)
            }
        }
    }

    private var subtitle: String {
        AppBranding.Groups.caption([AppBranding.Groups.members(group.memberCount),
                                    AppBranding.Groups.ownedBy(name: group.ownerName)])
    }
}

#Preview {
    ContentScreen {
        GroupHeader(group: MockGroupFixtures.make(now: .now)[0]).padding()
    }
}
