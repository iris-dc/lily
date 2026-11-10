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
