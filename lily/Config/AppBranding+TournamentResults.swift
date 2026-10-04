import Foundation

/// Copy of a tournament under way: the organiser's Start, the bracket and standings segments, the match cells and the
/// match sheet. An extension file because `AppBranding.Tournaments` is at the type-body limit.
nonisolated extension AppBranding.Tournaments {
    /// The menu item and the confirmation's button.
    static var start: String { localized("Start tournament") }
    /// The bracket, standings and matches segments before the start.
    static var notStarted: String { localized("The matches are drawn when the organiser starts the tournament.") }
    /// A side a feeder match has not decided yet, and a first-round bye.
    static var toBeDecided: String { localized("TBD") }
    static var bye: String { localized("Bye") }

    static func startConfirmationTitle(name: String) -> String {
        localized("Start \(name)?")
    }

    /// `entries` is the "4 of 8 teams" line, so the sentence needs no plural of its own.
    static func startConfirmationMessage(entries: String) -> String {
        localized("\(entries) are in. Registration closes and the matches are drawn.")
    }

    /// Why Start is disabled: the format's minimum, in teams or players.
    static func startNeeds(_ minimum: Int, teamSize: Int) -> String {
        teamSize > 1 ? localized("Needs at least \(minimum) teams") : localized("Needs at least \(minimum) players")
    }

    /// One match: its sheet, its status on the cells and in the list, and what each side may do.
    enum Match {
        static var title: String { localized("Match") }
        static var report: String { localized("Report result") }
        static var confirm: String { localized("Confirm result") }
        static var dispute: String { localized("Dispute") }
        static var record: String { localized("Record result") }
        static var walkover: String { localized("Walkover") }
        static var disputed: String { localized("Disputed") }
        static var awaitingOtherSide: String { localized("Waiting for the other side to confirm") }
        static var disputedNotice: String { localized("Disputed. The organiser decides.") }
        static var drawsNotAllowed: String { localized("Draws are not allowed in this tournament") }
        /// An en dash between the scores, and alone where there is no score yet; digits need no translation.
        static let scoreSeparator = "–"
        static var noScore: String { scoreSeparator }

        static func walkoverWinner(_ name: String) -> String {
            localized("\(name) wins by walkover")
        }

        /// "Jonas reported 3–2", above Confirm and Dispute.
        static func reported(by name: String, score: String) -> String {
            localized("\(name) reported \(score)")
        }

        static func score(_ scoreA: Int, _ scoreB: Int) -> String {
            "\(scoreA)\(scoreSeparator)\(scoreB)"
        }

        static func status(_ status: MatchStatus) -> String {
            switch status {
            case .pending: localized("To play")
            case .scheduled: localized("Scheduled")
            case .reported: localized("Reported")
            case .confirmed: localized("Played")
            case .walkover: walkover
            case .bye: bye
            }
        }
    }

    /// The column headers of a round robin's table, abbreviated as the language abbreviates them.
    enum Standings {
        static let rank = "#"
        static let difference = "+/-"
        static var played: String { localized("P") }
        static var won: String { localized("W") }
        static var drawn: String { localized("D") }
        static var lost: String { localized("L") }
        static var points: String { localized("Pts") }
    }
}
