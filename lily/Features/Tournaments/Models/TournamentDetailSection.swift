import Foundation

/// The segments under a tournament's cards: the bracket or the standings (by format) and the matches; both show an
/// empty state until the organiser started the tournament (`TournamentResultsSegment`). Who entered is no segment:
/// the People card's entries row pushes the full list (`TournamentPeopleView`).
nonisolated enum TournamentDetailSection: Hashable, CaseIterable, Sendable {
    case results, matches

    func title(for tournament: Tournament) -> String {
        switch self {
        case .results:
            tournament.format.drawsBracket ? AppBranding.Tournaments.bracketSection : AppBranding.Tournaments.standingsSection
        case .matches: AppBranding.Tournaments.matchesSection
        }
    }

    var symbolName: String {
        switch self {
        case .results: DesignTokens.Symbols.bracket
        case .matches: DesignTokens.Symbols.standings
        }
    }
}
