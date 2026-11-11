import Foundation

nonisolated extension AppBranding {
    /// The creation wizard's chrome: the kind page, the step titles with their captions and the progress mark's
    /// counter, Next and the discard confirmation. The fields keep their copy from each kind's existing `Create`
    /// namespace, and the final step's button reuses each kind's submit.
    enum Create {
        /// The kind page's title; its choice cards reuse the per-kind "New ..." titles.
        static var kindTitle: String { localized("What are you creating?") }
        static var kindEvent: String { Events.Create.title }
        static var kindGroup: String { Groups.Create.title }
        static var kindTournament: String { Tournaments.Create.title }

        /// The event steps' navigation titles, one idea per page.
        static var eventName: String { localized("Name") }
        static var eventType: String { localized("Type") }
        static var eventWhen: String { localized("When") }
        static var eventGroup: String { localized("Hosting group") }
        static var eventPlace: String { localized("Place") }
        static var eventPlayers: String { localized("Players") }
        static var eventDetails: String { localized("Details") }

        /// The one short line under a step title whose purpose needs extra knowledge: secondary ink, never accent,
        /// the app's plain voice. The plain steps (name, type, when) carry none.
        static var eventGroupCaption: String {
            localized("A group event lives on that group's page; without one it's open to everyone.")
        }
        /// The place caption is the Where rule the form already states: either half is enough.
        static var eventPlaceCaption: String { Events.Create.whereHint }
        static var eventPlayersCaption: String {
            localized("A cap closes the event when full; a number needed lets more join.")
        }
        static var eventDetailsCaption: String {
            localized("Price, what to expect, who you're looking for — all optional.")
        }

        /// The group steps' navigation titles; the names shared with the event flow reuse its copy.
        static var groupName: String { eventName }
        static var groupDescription: String { localized("Description") }
        static var groupType: String { eventType }
        static var groupVisibility: String { Groups.Create.visibility }
        static var groupPlace: String { eventPlace }
        static var groupPermissions: String { localized("Permissions") }

        static var groupDescriptionCaption: String {
            localized("What the group is about, for people deciding to join — optional.")
        }
        /// The public-place rule, stated one page before the Place page applies it (Visibility precedes Place).
        static var groupVisibilityCaption: String {
            localized("A public group names the place it plays at, so people nearby can find it.")
        }
        /// The same rule where it bites: only a public group must name its place.
        static var groupPlaceCaption: String {
            localized("A public group names the place it plays at; a private one may leave it out.")
        }
        static var groupPermissionsCaption: String {
            localized("What members may do — organisers can always do both.")
        }

        /// The tournament steps' navigation titles; the names shared with other flows reuse their copy.
        static var tournamentName: String { eventName }
        static var tournamentType: String { eventType }
        static var tournamentFormat: String { Tournaments.Create.format }
        static var tournamentSchedule: String { localized("Schedule") }
        static var tournamentGroup: String { eventGroup }
        static var tournamentPlace: String { eventPlace }
        static var tournamentEntries: String { Tournaments.Create.entries }
        static var tournamentWho: String { Groups.Create.visibility }
        static var tournamentDetails: String { eventDetails }

        static var tournamentScheduleCaption: String {
            localized("Entries close at the start, or earlier if you set a deadline.")
        }
        static var tournamentGroupCaption: String {
            localized("A group tournament lives on that group's page; without one it's open to everyone.")
        }
        /// Both halves are required here, unlike the event form's either-is-enough rule.
        static var tournamentPlaceCaption: String {
            localized("Tournaments need a named place and a spot on the map.")
        }
        static var tournamentEntriesCaption: String {
            localized("Alone or in teams of a size you set; entries close at the cap.")
        }
        static var tournamentWhoCaption: String {
            localized("Anyone can find and enter a public tournament; a private one is by invite.")
        }
        static var tournamentDetailsCaption: String { localized("What to expect — optional.") }
        /// Under the read-only who-may-join card once a hosting group is chosen.
        static var tournamentFollowsGroup: String {
            localized("A tournament in a group follows the group's visibility.")
        }

        /// The bottom bar's primary button on every step but the last.
        static var next: String { localized("Next") }

        /// The progress mark's accessibility label, the plural-safe counter; `number` counts from one.
        static func step(_ number: Int, of count: Int) -> String {
            localized("Step \(number) of \(count)")
        }

        /// The confirmation when Cancel or an interactive dismiss would drop a draft the user edited.
        static var discardTitle: String { localized("Discard this draft?") }
        static var discard: String { localized("Discard") }
        static var keepEditing: String { localized("Keep editing") }
    }
}
