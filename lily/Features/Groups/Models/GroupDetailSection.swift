import Foundation

/// The segments under a group's header: its games, its tournaments (while the feature is on) and its roster.
nonisolated enum GroupDetailSection: Hashable, CaseIterable, Sendable {
    case events, tournaments, members

    /// The segments the picker offers; tournaments only while the feature is switched on.
    static var available: [GroupDetailSection] {
        allCases.filter { $0 != .tournaments || AppConfig.FeatureFlags.tournaments }
    }

    var title: String {
        switch self {
        case .events: AppBranding.Groups.eventsSection
        case .tournaments: AppBranding.Tournaments.title
        case .members: AppBranding.Groups.membersSection
        }
    }
}
