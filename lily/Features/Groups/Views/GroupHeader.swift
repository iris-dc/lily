import SwiftUI

/// Top of the group detail: chips for type and visibility, the name, who runs it and how many are in, the description.
struct GroupHeader: View {
    let group: SportGroup

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let type = group.type {
                    EventTypeChip(type: type)
                }
                Label(group.visibility.displayName, systemImage: group.visibility.symbolName)
                    .lilyChip(.regular)
            }
            ScreenTitle(text: group.name, subtitle: subtitle)
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
