import Foundation

/// The segmented Home's three panes, in the picker's order: one of the caller's lists at a time, each carrying its
/// own copy so the screen reads everything from the segment. A segment behind a feature flag that is off is left out;
/// events always ship, so the offer is never empty.
nonisolated enum HomeSegment: CaseIterable, Hashable, Sendable {
    case events
    case tournaments
    case groups

    /// The segments the feature flags offer, in declaration order; the flags default to the build's.
    static func offered(groups: Bool = AppConfig.FeatureFlags.groups,
                        tournaments: Bool = AppConfig.FeatureFlags.tournaments) -> [HomeSegment] {
        allCases.filter { segment in
            switch segment {
            case .events: true
            case .tournaments: tournaments
            case .groups: groups
            }
        }
    }

    /// The segment's short label in the picker.
    var title: String {
        switch self {
        case .events: AppBranding.Home.eventsSegment
        case .tournaments: AppBranding.Home.tournamentsSegment
        case .groups: AppBranding.Home.groupsSegment
        }
    }

    /// The full-width create button's title, naming what the wizard will make.
    var createTitle: String {
        switch self {
        case .events: AppBranding.Home.createEvent
        case .tournaments: AppBranding.Home.createTournament
        case .groups: AppBranding.Home.createGroup
        }
    }

    /// What the create button seeds the wizard with.
    var creationKind: CreationKind {
        switch self {
        case .events: .event
        case .tournaments: .tournament
        case .groups: .group
        }
    }

    /// The empty hint's glyph.
    var symbolName: String {
        switch self {
        case .events: DesignTokens.Symbols.game
        case .tournaments: DesignTokens.Symbols.tournament
        case .groups: DesignTokens.Symbols.groups
        }
    }

    /// The empty hint's title.
    var emptyTitle: String {
        switch self {
        case .events: AppBranding.Home.noEventsTitle
        case .tournaments: AppBranding.Home.noTournamentsTitle
        case .groups: AppBranding.Home.noGroupsTitle
        }
    }

    /// The empty hint's message.
    var emptyMessage: String {
        switch self {
        case .events: AppBranding.Home.noGames
        case .tournaments: AppBranding.Home.noTournaments
        case .groups: AppBranding.Home.findGroups
        }
    }

    /// The note shown when the list is empty because its load failed.
    var failedMessage: String {
        switch self {
        case .events: AppBranding.Home.gamesLoadFailed
        case .tournaments: AppBranding.Tournaments.mineLoadFailed
        case .groups: AppBranding.Home.groupsLoadFailed
        }
    }

    /// The subtle count line over the segment's list.
    func countLine(_ count: Int) -> String {
        switch self {
        case .events: AppBranding.Home.eventCount(count)
        case .tournaments: AppBranding.Home.tournamentCount(count)
        case .groups: AppBranding.Home.groupCount(count)
        }
    }
}
