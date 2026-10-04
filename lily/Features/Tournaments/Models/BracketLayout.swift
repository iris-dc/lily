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

    static func roundCount(of matches: [TournamentMatch]) -> Int {
        matches.map(\.round).max() ?? 0
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

/// A round robin's table, computed as the backend computes it on every read: 3 / 1 / 0 points, ranked by points, then
/// score difference, then scored, then seed. The mock answers it; the screens read the backend's.
nonisolated enum RoundRobinStandings {
    private static let pointsForWin = 3
    private static let pointsForDraw = 1

    static func compute(entries: [TournamentEntry], matches: [TournamentMatch]) -> [TournamentStanding] {
        var rows: [String: Row] = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, Row(seed: $0.seed)) })
        for match in matches where match.isDecided {
            guard let sideA = match.entryAId, let sideB = match.entryBId else { continue }
            if match.status == .walkover {
                guard let winner = match.winnerEntryId else { continue }
                rows[winner]?.record(scored: 0, conceded: 0, outcome: .won)
                rows[winner == sideA ? sideB : sideA]?.record(scored: 0, conceded: 0, outcome: .lost)
            } else if let scoreA = match.scoreA, let scoreB = match.scoreB {
                rows[sideA]?.record(scored: scoreA, conceded: scoreB, outcome: Outcome(scoreA, scoreB))
                rows[sideB]?.record(scored: scoreB, conceded: scoreA, outcome: Outcome(scoreB, scoreA))
            }
        }
        let ranked = rows.sorted { lhs, rhs in
            let left = lhs.value, right = rhs.value
            if left.points != right.points { return left.points > right.points }
            if left.difference != right.difference { return left.difference > right.difference }
            if left.scored != right.scored { return left.scored > right.scored }
            return left.seed < right.seed
        }
        return ranked.enumerated().map { index, row in row.value.standing(entryID: row.key, rank: index + 1) }
    }

    private enum Outcome {
        case won, drawn, lost

        init(_ own: Int, _ other: Int) {
            self = own == other ? .drawn : (own > other ? .won : .lost)
        }
    }

    private struct Row {
        let seed: Int
        var played = 0
        var won = 0
        var drawn = 0
        var lost = 0
        var scored = 0
        var conceded = 0

        var points: Int { won * pointsForWin + drawn * pointsForDraw }
        var difference: Int { scored - conceded }

        mutating func record(scored: Int, conceded: Int, outcome: Outcome) {
            played += 1
            self.scored += scored
            self.conceded += conceded
            switch outcome {
            case .won: won += 1
            case .drawn: drawn += 1
            case .lost: lost += 1
            }
        }

        func standing(entryID: String, rank: Int) -> TournamentStanding {
            TournamentStanding(entryId: entryID,
                               rank: rank,
                               played: played,
                               won: won,
                               drawn: drawn,
                               lost: lost,
                               scored: scored,
                               conceded: conceded,
                               points: points)
        }
    }
}
