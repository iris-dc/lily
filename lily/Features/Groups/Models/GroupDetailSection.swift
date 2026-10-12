import Foundation

/// The segments under a group's header: its games, its tournaments (while the feature is on) and its roster.
nonisolated enum GroupDetailSection: Hashable, CaseIterable, Sendable {
    case events, tournaments, members

    /// The segments the picker offers `access`: events for everyone who can see the group, tournaments while the
    /// feature is on and the group is public or the caller is in it (a private group's list answers 404 to an outsider),
    /// the roster for whoever may see it.
    static func available(for access: GroupAccess,
                          in group: SportGroup,
                          tournamentsEnabled: Bool = AppConfig.FeatureFlags.tournaments) -> [GroupDetailSection] {
        allCases.filter { section in
            switch section {
            case .events: true
            case .tournaments: tournamentsEnabled && (group.isPublic || access.isMember)
            case .members: access.canSeeMembers(in: group)
            }
        }
    }

    var title: String {
        switch self {
        case .events: AppBranding.Groups.eventsSection
        case .tournaments: AppBranding.Tournaments.title
        case .members: AppBranding.Groups.membersSection
        }
    }
}
