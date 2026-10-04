import Foundation

nonisolated extension AppBranding {
    /// Copy of the tournament screens: the carousel and lists, the detail, the entries and the create sheet; the
    /// bracket, the standings and the matches are in `AppBranding+TournamentResults.swift`.
    enum Tournaments {
        static var title: String { localized("Tournaments") }
        /// The Home section, between the groups and the games.
        static var mineSection: String { localized("Your tournaments") }
        static var discoverTitle: String { localized("Discover tournaments") }
        static var tournament: String { localized("Tournament") }
        static var emptyTitle: String { localized("No tournaments yet") }
        static var emptyMessage: String { localized("Tournaments open for registration show up here.") }
        static var groupEmptyMessage: String { localized("Tournaments organised in this group show up here.") }
        static var loadFailedTitle: String { localized("Couldn't load tournaments") }
        static var mineLoadFailed: String { localized("Couldn't load your tournaments. Pull down to try again.") }
        static var discoverEmptyMessage: String { localized("Try another event type.") }
        static var unavailable: String { localized("This tournament is no longer available") }
        /// The status chip on cards and the detail.
        static var registrationStatus: String { localized("Registration open") }
        static var inProgressStatus: String { localized("In progress") }
        static var completedStatus: String { localized("Completed") }
        static var cancelledStatus: String { localized("Cancelled") }
        static var singleElimination: String { localized("Single elimination") }
        static var roundRobin: String { localized("Round robin") }
        /// The detail's notices and facts.
        static var organizingNotice: String { localized("You organise this tournament") }
        static var enteredNotice: String { localized("You're in") }
        static var startsAt: String { localized("Starts") }
        static var registrationCloses: String { localized("Registration closes") }
        static var full: String { localized("Tournament is full") }
        static var registrationClosed: String { localized("Registration closed") }
        /// The participation control and the entry rows.
        static var join: String { localized("Join tournament") }
        static var createTeam: String { localized("Create team") }
        static var joinTeam: String { localized("Join team") }
        static var leave: String { localized("Leave tournament") }
        static var captain: String { localized("Captain") }
        static var noEntries: String { localized("Nobody has entered yet") }
        /// The segments under the facts: who is in, the bracket or the standings, and the matches (the last two and the
        /// match sheet's copy are in `AppBranding+TournamentResults.swift`).
        static var playersSection: String { Events.Create.playersSection }
        static var teamsSection: String { localized("Teams") }
        static var bracketSection: String { localized("Bracket") }
        static var standingsSection: String { localized("Standings") }
        static var matchesSection: String { localized("Matches") }
        /// The toolbar menu, and the confirmations its destructive items ask for.
        static var cancel: String { localized("Cancel tournament") }
        static var removeEntry: String { localized("Remove entry") }
        /// The team-name sheet, opened by "Create team".
        static var teamNameTitle: String { localized("Name your team") }
        static var teamNamePlaceholder: String { localized("Team name") }
        /// Round titles of a bracket.
        static var finalRound: String { localized("Final") }
        static var semiFinals: String { localized("Semi-finals") }
        static var quarterFinals: String { localized("Quarter-finals") }

        static func organizedBy(name: String) -> String {
            localized("Organised by \(name)")
        }

        /// "3 of 8 teams" or "6 of 12 players", on cards and under the entries bar.
        static func entries(_ count: Int, of maxEntries: Int, teamSize: Int) -> String {
            teamSize > 1 ? localized("\(count) of \(maxEntries) teams") : players(count, of: maxEntries)
        }

        /// A team's roster size under its name: "2 of 5 players".
        static func players(_ count: Int, of size: Int) -> String {
            localized("\(count) of \(size) players")
        }

        static func seed(_ seed: Int) -> String {
            localized("Seed \(seed)")
        }

        /// The caption of a tournament's room on Chats: "Tournament · 6 players".
        static func roomCaption(players: Int) -> String {
            Groups.caption([tournament, Events.Create.capacity(players)])
        }

        static func cancelConfirmation(name: String) -> String {
            localized("Cancel \(name)? The chat stays, but no matches will be played.")
        }

        static func removeEntryConfirmation(name: String) -> String {
            localized("Remove \(name) from the tournament?")
        }

        static func leaveConfirmation(name: String) -> String {
            Groups.leaveConfirmation(groupName: name)
        }

        static func roundOf(_ entries: Int) -> String {
            localized("Round of \(entries)")
        }

        static func round(_ round: Int) -> String {
            localized("Round \(round)")
        }

        /// The line under the team-name field for one issue.
        static func teamNameMessage(for issue: TeamNameIssue) -> String {
            let limits = AppConfig.Tournaments.teamNameLength
            return switch issue {
            case .tooShort: localized("Give the team a name of at least \(limits.lowerBound) characters")
            case .tooLong: localized("Keep the team name under \(limits.upperBound) characters")
            }
        }

        /// The create and edit sheets; `title` doubles as the "+" menu's tournament item.
        enum Create {
            static var title: String { localized("New tournament") }
            static var editTitle: String { localized("Edit tournament") }
            /// The bar button: one word, so the inline title beside it is not squeezed to "New to…" (seen 2026-10-04).
            static var submit: String { Events.Create.menu }
            /// The group detail's menu item.
            static var menuItem: String { localized("Create tournament") }
            static var save: String { Groups.Create.save }
            static var cancel: String { Events.Create.cancel }
            static var tournamentSection: String { Tournaments.tournament }
            static var nameField: String { Groups.Create.nameField }
            static var namePlaceholder: String { localized("Kickers Cup") }
            static var descriptionPlaceholder: String { Events.Create.descriptionPlaceholder }
            static var eventType: String { Events.Create.eventType }
            static var format: String { localized("Format") }
            static var teamSize: String { localized("Team size") }
            static var individuals: String { localized("Individuals") }
            static var entries: String { localized("Entries") }
            static var draws: String { localized("Draws") }
            static var drawsAllowed: String { localized("Allowed") }
            static var drawsNotAllowed: String { localized("Not allowed") }
            static var registration: String { localized("Registration") }
            static var deadlineAtStart: String { localized("Until the start") }
            static var deadlineEarlier: String { localized("Earlier") }
            static var registrationClosesAt: String { localized("Closes") }
            static var startsAt: String { Events.Create.startsAt }
            static var whereSection: String { Events.Create.whereSection }
            static var detailsSection: String { Events.Create.detailsSection }
            static var visibility: String { Groups.Create.visibility }
            /// The mock repository has no profile to read the organiser's name from; the backend stamps the real one.
            static var mockOrganizerName: String { Groups.Create.mockOwnerName }

            /// The team-size stepper's label: players enter alone, or in teams of so many.
            static func teamSize(_ size: Int) -> String {
                size > 1 ? localized("Teams of \(size)") : individuals
            }

            /// The entries stepper's label.
            static func maxEntries(_ count: Int, teamSize: Int) -> String {
                teamSize > 1 ? localized("Up to \(count) teams") : localized("Up to \(count) players")
            }

            /// The line under a section for one issue, naming the limit from `AppConfig.Tournaments` where there is one;
            /// the entries cap depends on the format.
            static func message(for issue: TournamentDraft.Issue, format: TournamentFormat) -> String {
                textMessage(for: issue) ?? valueMessage(for: issue, format: format)
            }

            private static func textMessage(for issue: TournamentDraft.Issue) -> String? {
                let limits = AppConfig.Tournaments.self
                return switch issue {
                case .nameTooShort: localized("Give the tournament a name of at least \(limits.nameLength.lowerBound) characters")
                case .nameTooLong: localized("Keep the name under \(limits.nameLength.upperBound) characters")
                case .descriptionTooLong: localized("Keep the description under \(limits.descriptionMaxLength) characters")
                case .locationNameMissing: localized("Name the place")
                case .locationNameTooLong:
                    localized("Keep the place name under \(AppConfig.Events.Creation.locationNameMaxLength) characters")
                default: nil
                }
            }

            private static func valueMessage(for issue: TournamentDraft.Issue, format: TournamentFormat) -> String {
                let limits = AppConfig.Tournaments.self
                let range = format.entriesRange
                return switch issue {
                case .teamSizeOutOfRange:
                    localized("""
                    Between \(limits.teamSizeRange.lowerBound) and \(limits.teamSizeRange.upperBound) players per team
                    """)
                case .maxEntriesOutOfRange:
                    localized("Between \(range.lowerBound) and \(range.upperBound) entries")
                case .maxEntriesBelowEntries: localized("Keep at least as many entries as are already in")
                case .startsAtTooSoon:
                    localized("Pick a start at least \(AppConfig.Events.Creation.minimumLeadTimeMinutes) minutes from now")
                case .registrationClosesAfterStart: localized("Registration must close before the start")
                case .coordinateMissing: Events.Create.pickOnMap
                default: ""
                }
            }
        }
    }
}
