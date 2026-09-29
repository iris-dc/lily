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
        ConversationRow(caption: caption, hasUnread: hasUnread) {
            AvatarCircle(initials: group.name.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
        } title: {
            Label(group.name, systemImage: group.visibility.symbolName)
                .labelStyle(.titleThenIcon)
        }
    }

    private var caption: String {
        let isActiveToday = Calendar.current.isDate(group.lastActivityAt, inSameDayAs: now)
        return group.caption(suffix: isActiveToday ? AppBranding.Groups.activeTodayCaption : nil)
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
