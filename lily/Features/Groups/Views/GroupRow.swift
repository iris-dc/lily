import SwiftUI

/// One of the caller's groups as a conversation row: the group's mark, its name with the visibility glyph, a caption
/// with the member count, type and recent activity, and the unread dot. A direct conversation is a person row: the
/// other person's mark and name, no glyph, "Direct message" as the caption.
struct GroupRow: View {
    let group: SportGroup
    /// From `UnreadCenter`, which the live connection and the open chat keep current between Mine loads.
    let hasUnread: Bool
    /// Whether "Active today" applies is judged against this clock, so previews and screenshots are stable.
    var now: Date = .now

    var body: some View {
        if let counterpart = group.counterpart {
            GroupRowContent(name: counterpart.displayName,
                            visibility: nil,
                            caption: caption,
                            hasUnread: hasUnread,
                            isPerson: true)
        } else {
            GroupRowContent(name: group.name, visibility: group.visibility, caption: caption, hasUnread: hasUnread)
        }
    }

    private var caption: String {
        let isActiveToday = Calendar.current.isDate(group.lastActivityAt, inSameDayAs: now)
        return group.caption(suffix: isActiveToday ? AppBranding.Groups.activeTodayCaption : nil)
    }
}

/// The row itself, from the fields a row needs, so a group known only as a summary (a profile's "Groups in common")
/// draws the same as one of the caller's own. A person gets the accent mark every avatar that stands for one person
/// carries (the roster, the profile) where a group's is the secondary, and no glyph after the name.
struct GroupRowContent: View {
    let name: String
    /// The glyph after the name; `nil` for a person.
    let visibility: GroupVisibility?
    let caption: String
    let hasUnread: Bool
    var isPerson = false

    var body: some View {
        ConversationRow(caption: caption, hasUnread: hasUnread) {
            avatar
        } title: {
            title
        }
    }

    private var avatar: AvatarCircle {
        if isPerson {
            AvatarCircle(initials: name.initials, size: DesignTokens.Layout.avatarMedium)
        } else {
            AvatarCircle(initials: name.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
        }
    }

    @ViewBuilder private var title: some View {
        if let visibility {
            Label(name, systemImage: visibility.symbolName)
                .labelStyle(.titleThenIcon)
        } else {
            Text(name)
        }
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
