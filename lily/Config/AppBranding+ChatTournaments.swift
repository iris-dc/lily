import Foundation

/// The system rows of a tournament's room (tournaments plan, section 2.4): the start by format, a result and a dispute
/// with the server-rendered names, and the winner. Each has a line for when the wire carried no text or the tournament
/// is not known yet.
nonisolated extension AppBranding.Chat {
    static var matchResultFallback: String { localized("A result is in") }

    /// "The bracket is out" or "The schedule is out"; a generic line until the tournament's format is known.
    static func tournamentStarted(format: TournamentFormat?) -> String {
        switch format {
        case .singleElimination: localized("The bracket is out")
        case .roundRobin: localized("The schedule is out")
        case nil: localized("The tournament started")
        }
    }

    static func matchDisputed(_ text: String?) -> String {
        text.map { localized("Result disputed: \($0)") } ?? localized("Result disputed")
    }

    static func tournamentCompleted(winner: String?) -> String {
        winner.map { localized("\($0) won the tournament") } ?? localized("The tournament is over")
    }
}
