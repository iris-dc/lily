import SwiftUI

/// One of the caller's groups as a conversation row: the group's mark, its name with the visibility glyph, a caption
/// with the member count, type and recent activity, and the unread dot.
struct GroupRow: View {
    let group: SportGroup
    /// From `UnreadCenter`, which the live connection and the open chat keep current between Mine loads.
    let hasUnread: Bool
    /// Whether "Active today" applies is judged against this clock, so previews and screenshots are stable.
    var now: Date = .now

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: group.name.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Label(group.name, systemImage: group.visibility.symbolName)
                    .labelStyle(.titleThenIcon)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(caption)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            if hasUnread {
                UnreadDot()
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .contentShape(.rect)
    }

    private var caption: String {
        var parts = [AppBranding.Groups.members(group.memberCount)]
        if let type = group.type { parts.append(type.displayName) }
        if Calendar.current.isDate(group.lastActivityAt, inSameDayAs: now) { parts.append(AppBranding.Groups.activeTodayCaption) }
        return AppBranding.Groups.caption(parts)
    }
}

#Preview {
    ContentScreen {
        VStack {
            ForEach(MockGroupFixtures.make(now: .now).prefix(3)) { GroupRow(group: $0, hasUnread: $0.hasUnread) }
        }
        .padding()
    }
}
