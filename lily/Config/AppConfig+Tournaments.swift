import Foundation

nonisolated extension AppConfig {
    /// Tournaments: the limits mirrored from the backend's `TournamentsProperties` and `CreateTournamentRequest`, so a
    /// draft that passes here never earns a 400, and the lists' staleness rules.
    enum Tournaments {
        static let nameLength = 3...60
        static let descriptionMaxLength = 1000
        static let teamSizeRange = 1...11
        /// A team's name, required when `teamSize` is above one.
        static let teamNameLength = 2...40
        /// The entries a single-elimination bracket takes; a round robin is capped lower (`maxEntriesRoundRobin`).
        static let entriesRange = 2...64
        static let maxEntriesRoundRobin = 12
        static let minEntriesSingleElimination = 2
        static let minEntriesRoundRobin = 3
        /// Rooms of kind `tournament` a user may be in, and open tournaments one may organise.
        static let maxPerUser = 20
        static let maxOrganizedOpen = 10
        static let upcomingLimit = 50
        static let scoreRange = 0...999
        static let defaultMaxEntries = 8
        static let defaultTeamSize = 1
        /// A new draft proposes a start this far ahead, rounded up to the hour, and no deadline.
        static let defaultStartOffset: TimeInterval = 7 * 24 * 60 * 60
        /// Where the deadline lands when the organiser switches one on: a day before the start.
        static let defaultDeadlineLead: TimeInterval = 24 * 60 * 60
        /// The app's own margin for a start (the backend requires only the future); an edit has none.
        static let minimumLeadTime = Events.Creation.minimumLeadTime
        static let listStaleAfter: TimeInterval = 60
        static let retryAfterFailure: TimeInterval = 10

        /// The most entries a format takes: a start writes every match in one transaction, hence the caps.
        static func maxEntries(for format: TournamentFormat) -> Int {
            switch format {
            case .singleElimination: entriesRange.upperBound
            case .roundRobin: maxEntriesRoundRobin
            }
        }

        static func minEntries(for format: TournamentFormat) -> Int {
            switch format {
            case .singleElimination: minEntriesSingleElimination
            case .roundRobin: minEntriesRoundRobin
            }
        }

        static func entriesRange(for format: TournamentFormat) -> ClosedRange<Int> {
            entriesRange.lowerBound...maxEntries(for: format)
        }
    }
}

nonisolated extension AppConfig.FeatureFlags {
    #if DEBUG
    /// Tournaments: the carousel on Explore, the Home section, the group segment, the "+" item and the destinations.
    static let tournaments = true
    #else
    static let tournaments = false
    #endif
}

nonisolated extension AppConfig.API.Paths {
    static let tournaments = "/api/tournaments"

    static func tournament(id: String) -> String {
        "\(tournaments)/\(id)"
    }

    /// `POST` enters the caller (alone, or as a team's captain with a name).
    static func tournamentEntries(id: String) -> String {
        "\(tournament(id: id))/entries"
    }

    /// `DELETE` removes a whole entry (the organiser).
    static func tournamentEntry(id: String, entryID: String) -> String {
        "\(tournamentEntries(id: id))/\(entryID)"
    }

    /// `POST` joins the team.
    static func tournamentEntryMembers(id: String, entryID: String) -> String {
        "\(tournamentEntry(id: id, entryID: entryID))/members"
    }

    /// `DELETE` leaves the team, or removes a teammate (the captain) or a player (the organiser).
    static func tournamentEntryMember(id: String, entryID: String, userID: String) -> String {
        "\(tournamentEntryMembers(id: id, entryID: entryID))/\(userID)"
    }

    static func tournamentStart(id: String) -> String {
        "\(tournament(id: id))/start"
    }

    static func tournamentCancel(id: String) -> String {
        "\(tournament(id: id))/cancel"
    }

    static func tournamentMatch(id: String, matchID: String) -> String {
        "\(tournament(id: id))/matches/\(matchID)"
    }

    static func matchResult(id: String, matchID: String) -> String {
        "\(tournamentMatch(id: id, matchID: matchID))/result"
    }

    static func matchConfirm(id: String, matchID: String) -> String {
        "\(tournamentMatch(id: id, matchID: matchID))/confirm"
    }

    static func matchDispute(id: String, matchID: String) -> String {
        "\(tournamentMatch(id: id, matchID: matchID))/dispute"
    }

    static func matchWalkover(id: String, matchID: String) -> String {
        "\(tournamentMatch(id: id, matchID: matchID))/walkover"
    }

    static func matchSchedule(id: String, matchID: String) -> String {
        "\(tournamentMatch(id: id, matchID: matchID))/schedule"
    }

    /// The tournaments hosted in a group, under the group's read rule.
    static func groupTournaments(id: String) -> String {
        "\(group(id: id))/tournaments"
    }

    /// `GET`: the people an entrant or the organiser may invite, in the group invitee shape.
    static func tournamentInvitees(id: String) -> String {
        "\(tournament(id: id))/invitees"
    }

    /// `POST {userId}`: sends the invite; the invitee answers it from their inbox.
    static func tournamentInvites(id: String) -> String {
        "\(tournament(id: id))/invites"
    }
}
