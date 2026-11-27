import Foundation

/// The segments under a group's People card: its games and its tournaments (while the feature is on). The roster is
/// no segment: the People card's rows push it (`GroupMembersView`).
nonisolated enum GroupDetailSection: Hashable, CaseIterable, Sendable {
    case events, tournaments

    /// The segments the picker offers `access`: events for everyone who can see the group, tournaments while the
    /// feature is on and the group is public or the caller is in it (a private group's list answers 404 to an outsider).
    static func available(for access: GroupAccess,
                          in group: SportGroup,
                          tournamentsEnabled: Bool = AppConfig.FeatureFlags.tournaments) -> [GroupDetailSection] {
        allCases.filter { section in
            switch section {
            case .events: true
            case .tournaments: tournamentsEnabled && (group.isPublic || access.isMember)
            }
        }
    }

    var title: String {
        switch self {
        case .events: AppBranding.Groups.eventsSection
        case .tournaments: AppBranding.Tournaments.title
        }
    }
}
