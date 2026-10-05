import Foundation

/// Everything that identifies the product to the user. Change here, and every screen follows. Every line of copy is
/// read through `localized(_:)`, so it comes back in the app's language (`AppLocale`); the English text is the key.
nonisolated enum AppBranding {
    static let name = "iskra"

    /// Copy shared by every event surface, so a preview card and a capacity bar can never disagree.
    enum Events {
        static var full: String { localized("Full") }

        /// Filter panel on Explore, dropped down from the toolbar button.
        enum Filter {
            static var title: String { localized("Filters") }
            static var eventType: String { localized("Event type") }
            static var anyType: String { localized("Any type") }
            /// The reference point is the user's position for now; a chosen place is the intended next step.
            static var distance: String { localized("Distance from me") }
            static var anywhere: String { localized("Any") }
            /// Shown while the user's position is unknown: still pending, timed out or denied.
            static var locationUnavailable: String { localized("Distance needs your location") }
            static var maxPrice: String { localized("Max price") }
            static var anyPrice: String { localized("Any") }
            static var freeOnly: String { localized("Free only") }
            static var level: String { localized("Level") }
            static var anyLevel: String { localized("Any level") }
            static var dates: String { localized("Specific dates") }
            static var from: String { localized("From") }
            static var until: String { localized("Until") }
            static var openSpotsOnly: String { localized("Open spots only") }
            static var reset: String { localized("Reset") }
            static var done: String { localized("Done") }
            static var emptyTitle: String { localized("Nothing matches") }
            static var emptyMessage: String { localized("Try fewer filters, or show all events.") }
            static var showAll: String { localized("Show all events") }
            /// VoiceOver value of the toolbar button: whether any criterion is active.
            static var activeValue: String { localized("On") }
            static var inactiveValue: String { localized("Off") }
        }

        /// Optional event details on the detail screen. `free` is the model fallback in `SportEvent.priceText` and
        /// `Price.text`; cards and the detail screen check `isFree` first and never render it.
        static var free: String { localized("Free") }
        /// The dot between caption parts. `EventCard` draws it as its own view; `captionSeparator` pads it for
        /// `joined(separator:)` ("in 3 hours · 4 spots left · €5").
        static let separatorGlyph = "·"
        static let captionSeparator = " \(separatorGlyph) "
        static var lookingForTitle: String { localized("Looking for") }

        static var loadFailedTitle: String { localized("Couldn't load events") }
        /// Heading over the Explore cards while the groups carousel sits above them.
        static var eventsSection: String { localized("Events") }
        static var loadFailedMessage: String { localized("Pull down to try again.") }

        /// The create sheet, opened from the floating "+" on Explore; `title` doubles as the "+" menu's game item.
        enum Create {
            /// VoiceOver label of the floating "+", a menu with a game and a group.
            static var menu: String { localized("Create") }
            static var title: String { localized("New game") }
            static var submit: String { localized("Create game") }
            static var cancel: String { localized("Cancel") }
            static var gameSection: String { localized("Game") }
            static var titleField: String { localized("Title") }
            static var titlePlaceholder: String { localized("Sunset 5-a-side") }
            static var eventType: String { localized("Event type") }
            static var startsAt: String { localized("When") }
            static var whereSection: String { localized("Where") }
            static var locationNamePlaceholder: String { localized("Place name") }
            static var pickOnMap: String { localized("Set the spot on the map") }
            /// Value of the map row while the draft has no coordinate yet.
            static var spotNotSet: String { localized("Not set") }
            /// Value of the map row once a spot is set: `%f` latitude, `%f` longitude, four decimals (about 10 m). Never
            /// localized: a comma for the decimals would collide with the one between them.
            static let coordinateFormat = "%.4f, %.4f"
            static var mapTitle: String { localized("Where is it?") }
            static var mapHint: String { localized("Move the map until the pin sits on the spot.") }
            static var mapDone: String { localized("Done") }
            static var playersSection: String { localized("Players") }
            static var detailsSection: String { localized("Details (optional)") }
            static var descriptionPlaceholder: String { localized("What to expect") }
            static var lookingForPlaceholder: String { localized("Who are you looking for?") }
            static var level: String { localized("Level") }
            static var anyLevel: String { localized("Any level") }
            static var price: String { localized("Price per person") }
            static var pricePlaceholder: String { localized("Free") }
            /// The mock repository has no profile to read the host's name from; the backend stamps the real one.
            static var mockHostName: String { localized("You") }

            /// Stepper label: `count` is the capacity, the host included.
            static func capacity(_ count: Int) -> String {
                localized("\(count) players")
            }

            static func coordinateText(_ coordinate: Coordinate) -> String {
                String(format: coordinateFormat, coordinate.latitude, coordinate.longitude)
            }

            /// The line under a field for one issue, naming the limit from `AppConfig.Events.Creation` where there is one.
            static func message(for issue: EventDraft.Issue) -> String {
                textMessage(for: issue) ?? valueMessage(for: issue)
            }

            /// The text fields: missing or over their length.
            private static func textMessage(for issue: EventDraft.Issue) -> String? {
                let limits = AppConfig.Events.Creation.self
                return switch issue {
                case .titleMissing: localized("Give the game a title")
                case .titleTooLong: localized("Keep the title under \(limits.titleMaxLength) characters")
                case .locationNameMissing: localized("Name the place")
                case .locationNameTooLong: localized("Keep the place name under \(limits.locationNameMaxLength) characters")
                case .descriptionTooLong: localized("Keep the description under \(limits.descriptionMaxLength) characters")
                case .lookingForTooLong: localized("Keep it under \(limits.lookingForMaxLength) characters")
                default: nil
                }
            }

            /// When, where on the map, how many and how much.
            private static func valueMessage(for issue: EventDraft.Issue) -> String {
                let limits = AppConfig.Events.Creation.self
                return switch issue {
                case .startsAtTooSoon: localized("Pick a start at least \(limits.minimumLeadTimeMinutes) minutes from now")
                case .coordinateMissing: pickOnMap
                case .capacityOutOfRange:
                    localized("Between \(limits.capacityRange.lowerBound) and \(limits.capacityRange.upperBound) players")
                case .capacityBelowParticipants: localized("Keep at least as many spots as players who joined")
                case .priceOutOfRange: localized("Enter a price with at most two decimals")
                default: ""
                }
            }
        }

        /// Segmented toolbar picker on Explore; the label is what VoiceOver reads for the control.
        static var presentationPicker: String { localized("View") }
        static var listPresentation: String { localized("List") }
        static var mapPresentation: String { localized("Map") }

        /// Open-spot counts for compact cards.
        static func spotsLeft(_ count: Int) -> String {
            localized("\(count) spots left")
        }

        /// Under the capacity bar, counting the way the bar fills: participants of capacity. The copy of a game that
        /// allows extras is in `AppBranding+Capacity.swift`.
        static func joined(_ count: Int, of capacity: Int) -> String {
            localized("\(count) of \(capacity) joined")
        }

        static func perPerson(_ priceText: String) -> String {
            localized("\(priceText) per person")
        }

        static func level(_ levelName: String) -> String {
            localized("\(levelName) level")
        }
    }

    /// The landing's slides are `AppBranding.Intro`; these are the two buttons under them.
    static var landingPrimaryAction: String { localized("Find a game near you") }
    static var signInPrompt: String { localized("Already have an account?") }
    static var signInAction: String { localized("Sign in") }

    static var guestProfileTitle: String { localized("You're browsing as a guest") }
    static var guestProfileMessage: String { localized("Sign in to create events, join games and chat with players.") }

    static var signInSheetTitle: String { localized("Welcome back") }
    static var signInSheetSubtitle: String { localized("Sign in to create games, join and chat.") }

    /// Sign-in buttons: `providerName` is the provider's display name.
    static func signInButtonTitle(for providerName: String) -> String {
        localized("Continue with \(providerName)")
    }

    /// VoiceOver value of a provider button while its sign-in is in flight.
    static var signingInStatus: String { localized("Signing in") }
    static var dismissAction: String { localized("Dismiss") }
    static var signOutAction: String { localized("Sign out") }

    /// Email form inside the sign-in sheet. The sign-in title is `signInSheetTitle`, so sheet and form cannot drift.
    static var emailSignInSubtitle: String { localized("Use your email and a password.") }
    static var emailFieldPlaceholder: String { localized("Email") }
    static var passwordFieldPlaceholder: String { localized("Password") }
    static var signUpSheetTitle: String { localized("Create your account") }
    static var signUpAction: String { localized("Sign up") }
    static var signUpPrompt: String { localized("New here? Create an account") }

    /// `minimumLength` is the minimum password length from `AppConfig.Auth`.
    static func passwordHint(minimumLength: Int) -> String {
        localized("At least \(minimumLength) characters")
    }

    /// Confirmation step of the email form, after a sign-up (or a sign-in refused as unconfirmed).
    static var confirmEmailTitle: String { localized("Check your email") }
    static var confirmationCodePlaceholder: String { localized("Confirmation code") }
    static var confirmAction: String { localized("Confirm") }
    static var resendCodeAction: String { localized("Resend code") }
    static var backToSignInAction: String { localized("Back to sign in") }

    static func confirmEmailSubtitle(email: String) -> String {
        localized("We sent a code to \(email)")
    }

    /// Tab titles double as navigation titles.
    static var homeTitle: String { localized("Home") }
    static var exploreTitle: String { localized("Explore") }
    static var profileTitle: String { localized("Profile") }

    static var exploreEmptyTitle: String { localized("Nothing yet") }
    static var exploreEmptyMessage: String { localized("New games show up here as people create them.") }

    /// The Home tab: the caller's groups and games, and the states around them.
    enum Home {
        static var groupsSection: String { localized("Your groups") }
        static var gamesSection: String { localized("Your games") }
        static var noGroups: String { localized("No groups yet. Find one on Explore, or create your own.") }
        static var noGames: String { localized("Games you join or host will appear here.") }
        static var emptyTitle: String { localized("Nothing here yet") }
        static var emptyMessage: String { localized("Games you join or host and groups you belong to appear here.") }
        static var exploreAction: String { localized("Explore") }
        static var loadFailedTitle: String { localized("Couldn't load your groups and games") }
        static var guestMessage: String { localized("Sign in to see your groups and the games you join or host.") }
        static var groupsLoadFailed: String { localized("Couldn't load your groups. Pull down to try again.") }
        static var gamesLoadFailed: String { localized("Couldn't load your games. Pull down to try again.") }
    }

    /// Event detail.
    static var joinAction: String { localized("Join") }
    static var leaveAction: String { localized("Leave") }
    static var eventFullAction: String { localized("Event is full") }
    static var hostingNotice: String { localized("You host this game") }

    static func hostedByTitle(for hostName: String) -> String {
        localized("Hosted by \(hostName)")
    }
}
