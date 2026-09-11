import Foundation

/// Everything that identifies the product to the user. Change here, and every screen follows.
nonisolated enum AppBranding {
    static let name = "lily"

    /// Copy shared by every event surface, so a preview card and a capacity bar can never disagree.
    enum Events {
        static let full = "Full"
        /// Open-spot counts: `%ld` is the number of spots, and in the long form also the capacity.
        static let oneSpotLeftFormat = "%ld spot left"
        static let spotsLeftFormat = "%ld spots left"
        static let spotsOfCapacityLeftFormat = "%ld of %ld spots left"

        static let loadFailedTitle = "Couldn't load events"
        static let loadFailedMessage = "Pull down to try again."

        static func spotsLeft(_ count: Int) -> String {
            String(format: count == 1 ? oneSpotLeftFormat : spotsLeftFormat, count)
        }

        static func spotsLeft(_ count: Int, of capacity: Int) -> String {
            String(format: spotsOfCapacityLeftFormat, count, capacity)
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
    static let eventFullAction = "Event is full"
    static let joinComingSoon = "Joining arrives with the backend."
    static let hostedByFormat = "Hosted by %@"

    static func hostedByTitle(for hostName: String) -> String {
        String(format: hostedByFormat, hostName)
    }
}
