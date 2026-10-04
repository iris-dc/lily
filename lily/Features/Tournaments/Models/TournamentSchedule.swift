import Foundation

/// The pairings a start draws, in pure Swift, for the mock alone: the backend draws the real ones, and the shared
/// fixtures (`lilyTests/Fixtures/pairings`) pin both to the same contract. Seeds arrive in registration order
/// (`seeds[0]` is seed 1); a match id is `r<round>p<position>` with two- and three-digit padding.
nonisolated enum TournamentSchedule {
    /// One drawn match, exactly as the backend's `Match` shows it right after a start: no scores, no schedule, and the
    /// optionals absent rather than null, so the fixtures decode into it directly.
    struct Pairing: Hashable, Codable, Sendable {
        let id: String
        let round: Int
        let position: Int
        var entryAId: String?
        var entryBId: String?
        var status: MatchStatus = .pending
        var winnerEntryId: String?
        var nextMatchId: String?
        var nextSlot: MatchSlot?
    }

    static func pairings(format: TournamentFormat, seeds: [String]) -> [Pairing] {
        switch format {
        case .singleElimination: singleElimination(seeds: seeds)
        case .roundRobin: roundRobin(seeds: seeds)
        }
    }

    static func matchID(round: Int, position: Int) -> String {
        String(format: "r%02dp%03d", round, position)
    }

    /// Bracket size B = the next power of two at or above N; the byes (B - N) go to the top seeds. Round 1, position p
    /// pairs bracket slots 2p-1 and 2p; round r, position p feeds round r+1, position ceil(p/2), slot a when p is odd.
    /// A round-1 match with only its A side is a bye: its entry is the winner and already stands in the next match.
    private static func singleElimination(seeds: [String]) -> [Pairing] {
        let count = seeds.count
        var size = 1
        var rounds = 0
        while size < count {
            size *= 2
            rounds += 1
        }
        let order = bracketOrder(size: size)
        var matches: [Pairing] = []
        for round in 1...max(rounds, 1) {
            let matchCount = size >> round
            for position in 1...max(matchCount, 1) {
                var match = Pairing(id: matchID(round: round, position: position), round: round, position: position)
                if round == 1 {
                    let seedA = order[2 * position - 2], seedB = order[2 * position - 1]
                    if seedA <= count { match.entryAId = seeds[seedA - 1] }
                    if seedB <= count { match.entryBId = seeds[seedB - 1] }
                }
                if round < rounds {
                    match.nextMatchId = matchID(round: round + 1, position: (position + 1) / 2)
                    match.nextSlot = position.isMultiple(of: 2) ? .b : .a
                }
                matches.append(match)
            }
        }
        return advancingByes(matches)
    }

    /// The standard bracket order: start with [1]; for each doubling to size k every seed s is followed by k + 1 - s,
    /// so eight gives [1, 8, 4, 5, 2, 7, 3, 6].
    private static func bracketOrder(size: Int) -> [Int] {
        var order = [1]
        var current = 1
        while current < size {
            current *= 2
            order = order.flatMap { [$0, current + 1 - $0] }
        }
        return order
    }

    private static func advancingByes(_ matches: [Pairing]) -> [Pairing] {
        var matches = matches
        for index in matches.indices where matches[index].round == 1 {
            let match = matches[index]
            guard let entry = match.entryAId, match.entryBId == nil else { continue }
            matches[index].status = .bye
            matches[index].winnerEntryId = entry
            guard let nextID = match.nextMatchId, let slot = match.nextSlot,
                  let next = matches.firstIndex(where: { $0.id == nextID }) else { continue }
            switch slot {
            case .a: matches[next].entryAId = entry
            case .b: matches[next].entryBId = entry
            }
        }
        return matches
    }

    /// The circle method: the seeds in order plus a "sits out" marker for an odd count, rounds = table size - 1; in each
    /// round table[i] meets table[L-1-i], the pair holding the marker skipped and positions compacted; then the first
    /// stays and the rest rotate one step to the right.
    private static func roundRobin(seeds: [String]) -> [Pairing] {
        var table: [String?] = seeds
        if !table.count.isMultiple(of: 2) { table.append(nil) }
        let length = table.count
        var matches: [Pairing] = []
        for round in 1..<max(length, 2) {
            var position = 0
            for index in 0..<(length / 2) {
                guard let entryA = table[index], let entryB = table[length - 1 - index] else { continue }
                position += 1
                matches.append(Pairing(id: matchID(round: round, position: position),
                                       round: round,
                                       position: position,
                                       entryAId: entryA,
                                       entryBId: entryB))
            }
            table = [table[0], table[length - 1]] + table[1..<(length - 1)]
        }
        return matches
    }
}
