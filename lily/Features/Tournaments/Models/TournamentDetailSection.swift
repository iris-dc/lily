import Foundation

/// The segments under a tournament's facts: who is in, the bracket or the standings (by format), and the matches; the
/// last two show an empty state until the organiser started the tournament (`TournamentResultsSegment`).
nonisolated enum TournamentDetailSection: Hashable, CaseIterable, Sendable {
    case entries, results, matches

    func title(for tournament: Tournament) -> String {
        switch self {
        case .entries: tournament.isTeam ? AppBranding.Tournaments.teamsSection : AppBranding.Tournaments.playersSection
        case .results:
            tournament.format == .roundRobin ? AppBranding.Tournaments.standingsSection : AppBranding.Tournaments.bracketSection
        case .matches: AppBranding.Tournaments.matchesSection
        }
    }

    var symbolName: String {
        switch self {
        case .entries: DesignTokens.Symbols.lookingFor
        case .results: DesignTokens.Symbols.bracket
        case .matches: DesignTokens.Symbols.standings
        }
    }
}
