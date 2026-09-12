import Foundation

/// Everything that identifies the product to the user. Change here, and every screen follows.
nonisolated enum AppBranding {
    static let name = "lily"

    /// Copy shared by every event surface, so a preview card and a capacity bar can never disagree.
    enum Events {
        static let full = "Full"
        /// Open-spot counts for compact cards: `%ld` is the number of spots.
        static let oneSpotLeftFormat = "%ld spot left"
        static let spotsLeftFormat = "%ld spots left"
        /// Under the capacity bar, counting the same way the bar fills: `%ld` participants of `%ld` capacity.
        static let joinedOfCapacityFormat = "%ld of %ld joined"

        /// Filter panel on Explore, dropped down from the toolbar button.
        enum Filter {
            static let title = "Filters"
            static let eventType = "Event type"
            static let anyType = "Any type"
            /// The reference point is the user's position for now; a chosen place is the intended next step.
            static let distance = "Distance from me"
            static let anywhere = "Any"
            /// Shown while the user's position is unknown: still pending, timed out or denied.
            static let locationUnavailable = "Distance needs your location"
            static let maxPrice = "Max price"
            static let anyPrice = "Any"
            static let freeOnly = "Free only"
            static let level = "Level"
            static let anyLevel = "Any level"
            static let dates = "Specific dates"
            static let from = "From"
            static let until = "Until"
            static let openSpotsOnly = "Open spots only"
            static let reset = "Reset"
            static let done = "Done"
            static let emptyTitle = "Nothing matches"
            static let emptyMessage = "Try fewer filters, or show all events."
            static let showAll = "Show all events"
            /// VoiceOver value of the toolbar button: whether any criterion is active.
            static let activeValue = "On"
            static let inactiveValue = "Off"
        }

        /// Optional event details on the detail screen. `free` is the model fallback in `SportEvent.priceText` and
        /// `Price.text`; cards and the detail screen check
        /// `isFree` first and never render it.
        static let free = "Free"
        /// The dot between caption parts. `EventCard` draws it as its own view; `captionSeparator` pads it for
        /// `joined(separator:)` ("in 3 hours · 4 spots left · €5").
        static let separatorGlyph = "·"
        static let captionSeparator = " \(separatorGlyph) "
        static let perPersonFormat = "%@ per person"
        static let levelFormat = "%@ level"
        static let lookingForTitle = "Looking for"

        static let loadFailedTitle = "Couldn't load events"
        static let loadFailedMessage = "Pull down to try again."

        /// Segmented toolbar picker on Explore; the label is what VoiceOver reads for the control.
        static let presentationPicker = "View"
        static let listPresentation = "List"
        static let mapPresentation = "Map"

        static func spotsLeft(_ count: Int) -> String {
            String(format: count == 1 ? oneSpotLeftFormat : spotsLeftFormat, count)
        }

        static func joined(_ count: Int, of capacity: Int) -> String {
            String(format: joinedOfCapacityFormat, count, capacity)
        }

        static func perPerson(_ priceText: String) -> String {
            String(format: perPersonFormat, priceText)
        }

        static func level(_ levelName: String) -> String {
            String(format: levelFormat, levelName)
        }
    }

    /// Landing headline, one line per element. The last line is highlighted in the accent color.
    static let headline = ["Pick a sport.", "Find your people.", "Play tonight."]
    static let subheadline = "Real games near you, organised by people like you. Join one or start your own."

    static let landingPrimaryAction = "Find a game near you"
    static let signInPrompt = "Already have an account?"
    static let signInAction = "Sign in"

    static let guestProfileTitle = "You're browsing as a guest"
    static let guestProfileMessage = "Sign in to create events, join games and chat with players."

    static let signInSheetTitle = "Welcome back"
    static let signInSheetSubtitle = "Sign in to create games, join and chat."

    /// Copy templates for sign-in buttons: `%@` is the provider's display name.
    static let signInButtonFormat = "Continue with %@"

    static func signInButtonTitle(for providerName: String) -> String {
        String(format: signInButtonFormat, providerName)
    }

    /// VoiceOver value of a provider button while its sign-in is in flight.
    static let signingInStatus = "Signing in"
    static let dismissAction = "Dismiss"
    static let signOutAction = "Sign out"

    /// Email form inside the sign-in sheet. The sign-in title is `signInSheetTitle`, so sheet and form cannot drift.
    static let emailSignInSubtitle = "Use your email and a password."
    static let emailFieldPlaceholder = "Email"
    static let passwordFieldPlaceholder = "Password"
    static let signUpSheetTitle = "Create your account"
    static let signUpAction = "Sign up"
    static let signUpPrompt = "New here? Create an account"
    /// `%d` is the minimum password length from `AppConfig.Auth`.
    static let passwordHintFormat = "At least %d characters"

    static func passwordHint(minimumLength: Int) -> String {
        String(format: passwordHintFormat, minimumLength)
    }

    /// Tab titles double as navigation titles.
    static let exploreTitle = "Explore"
    static let myEventsTitle = "My Events"
    static let profileTitle = "Profile"

    static let exploreEmptyTitle = "Nothing yet"
    static let exploreEmptyMessage = "New games show up here as people create them."
    static let myEventsEmptyTitle = "No events yet"
    static let myEventsEmptyMessage = "Games you join or host will appear here."

    /// Event detail. `%@` in `hostedByFormat` is the host's display name.
    static let joinAction = "Join"
    static let leaveAction = "Leave"
    static let eventFullAction = "Event is full"
    static let hostingNotice = "You host this game"
    static let hostedByFormat = "Hosted by %@"

    static func hostedByTitle(for hostName: String) -> String {
        String(format: hostedByFormat, hostName)
    }
}
