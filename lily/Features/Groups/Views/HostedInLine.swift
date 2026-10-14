import SwiftUI

/// "Hosted in <group>": a link to the group when it is public and live, its name alone otherwise; a private
/// group's game says so, since the link is withheld on purpose. The event detail and the tournament header draw it
/// under the title.
struct HostedInLine: View {
    let group: EventGroupRef

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if group.isLinkable {
                NavigationLink(value: group) {
                    label.foregroundStyle(Color.lilyAccent)
                }
                .buttonStyle(.plain)
            } else {
                label.foregroundStyle(.secondary)
            }
            if group.isPrivate {
                Text(AppBranding.Groups.membersOnly)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private var label: some View {
        Label(AppBranding.Groups.hostedIn(groupName: group.name), systemImage: DesignTokens.Symbols.groups)
    }
}
