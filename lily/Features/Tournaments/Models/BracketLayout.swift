import Foundation

/// Pure layout of a tournament's matches for the screens: the rounds as columns, and what each round is called.
nonisolated enum BracketLayout {
    /// The matches by round, each round by position; empty before the start.
    static func columns(of matches: [TournamentMatch]) -> [[TournamentMatch]] {
        let byRound = Dictionary(grouping: matches, by: \.round)
        return byRound.keys.sorted().map { round in
            (byRound[round] ?? []).sorted { $0.position < $1.position }
        }
    }

    /// The height a cell of `round` (1-based) takes in its column, the cell centred in it: twice the slot of the round
    /// before plus the gap, so a match sits level with the middle of the two matches that feed it.
    static func slotHeight(round: Int, cellHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        let feeders = CGFloat(1 << max(round - 1, 0))
        return (cellHeight + spacing) * feeders - spacing
    }

    /// Final, Semi-finals, Quarter-finals and "Round of N" for a bracket, counted back from the last round; a round
    /// robin's rounds are numbered.
    static func roundTitle(round: Int, of rounds: Int, format: TournamentFormat) -> String {
        guard format == .singleElimination else { return AppBranding.Tournaments.round(round) }
        switch rounds - round {
        case 0: return AppBranding.Tournaments.finalRound
        case 1: return AppBranding.Tournaments.semiFinals
        case 2: return AppBranding.Tournaments.quarterFinals
        case let depth: return AppBranding.Tournaments.roundOf(1 << (depth + 1))
        }
    }
}
