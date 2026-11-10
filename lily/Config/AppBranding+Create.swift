import Foundation

nonisolated extension AppBranding {
    /// The creation wizard's chrome: the kind page, the step titles and counter, Next and the discard confirmation.
    /// The fields keep their copy from each kind's existing `Create` namespace, and the final step's button reuses
    /// each kind's submit.
    enum Create {
        /// The kind page's title; its choice cards reuse the per-kind "New ..." titles.
        static var kindTitle: String { localized("What are you creating?") }
        static var kindEvent: String { Events.Create.title }
        static var kindGroup: String { Groups.Create.title }
        static var kindTournament: String { Tournaments.Create.title }

        /// The event steps' navigation titles.
        static var eventBasics: String { localized("Basics") }
        static var eventPlace: String { localized("Place") }
        static var eventPlayersAndDetails: String { localized("Players and details") }

        /// The bottom bar's primary button on every step but the last.
        static var next: String { localized("Next") }

        /// The counter under a step's title, the wizard's step indicator; `number` counts from one.
        static func step(_ number: Int, of count: Int) -> String {
            localized("Step \(number) of \(count)")
        }

        /// The confirmation when Cancel or an interactive dismiss would drop a draft the user edited.
        static var discardTitle: String { localized("Discard this draft?") }
        static var discard: String { localized("Discard") }
        static var keepEditing: String { localized("Keep editing") }
    }
}
