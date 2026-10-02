import Foundation

/// Everything that identifies the product to the user. Change here, and every screen follows.
nonisolated enum AppBranding {
    static let name = "iskra"

    /// Copy shared by every event surface, so a preview card and a capacity bar can never disagree.
    enum Events {
        static let full = "Full"
        /// Open-spot counts for compact cards: `%ld` is the number of spots.
        static let oneSpotLeftFormat = "%ld spot left"
        static let spotsLeftFormat = "%ld spots left"
        /// Under the capacity bar, counting the same way the bar fills: `%ld` participants of `%ld` capacity. The copy
        /// of a game that allows extras is in `AppBranding+Capacity.swift`.
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
        /// Heading over the Explore cards while the groups carousel sits above them.
        static let eventsSection = "Events"
        static let loadFailedMessage = "Pull down to try again."

        /// The create sheet, opened from the floating "+" on Explore; `title` doubles as the "+" menu's game item.
        enum Create {
            /// VoiceOver label of the floating "+", a menu with a game and a group.
            static let menu = "Create"
            static let title = "New game"
            static let submit = "Create game"
            static let cancel = "Cancel"
            static let gameSection = "Game"
            static let titleField = "Title"
            static let titlePlaceholder = "Sunset 5-a-side"
            static let eventType = "Event type"
            static let startsAt = "When"
            static let whereSection = "Where"
            static let locationNamePlaceholder = "Place name"
            static let pickOnMap = "Set the spot on the map"
            /// Value of the map row while the draft has no coordinate yet.
            static let spotNotSet = "Not set"
            /// Value of the map row once a spot is set: `%f` latitude, `%f` longitude, four decimals (about 10 m).
            static let coordinateFormat = "%.4f, %.4f"
            static let mapTitle = "Where is it?"
            static let mapHint = "Move the map until the pin sits on the spot."
            static let mapDone = "Done"
            static let playersSection = "Players"
            /// Stepper label: `%ld` is the capacity, the host included.
            static let capacityFormat = "%ld players"
            static let detailsSection = "Details (optional)"
            static let descriptionPlaceholder = "What to expect"
            static let lookingForPlaceholder = "Who are you looking for?"
            static let level = "Level"
            static let anyLevel = "Any level"
            static let price = "Price per person"
            static let pricePlaceholder = "Free"
            /// The mock repository has no profile to read the host's name from; the backend stamps the real one.
            static let mockHostName = "You"
            /// Guests are shown the sign-in sheet instead; the sheet's own title and subtitle already explain why.
            /// One line per `EventDraft.Issue`, shown under the field it concerns.
            static let issueTitleMissing = "Give the game a title"
            static let issueTitleTooLong = "Keep the title under %ld characters"
            static let issueStartsAtTooSoon = "Pick a start at least %ld minutes from now"
            static let issueLocationNameMissing = "Name the place"
            static let issueLocationNameTooLong = "Keep the place name under %ld characters"
            static let issueCoordinateMissing = "Set the spot on the map"
            static let issueCapacityOutOfRange = "Between %ld and %ld players"
            static let issueCapacityBelowParticipants = "Keep at least as many spots as players who joined"
            static let issueDescriptionTooLong = "Keep the description under %ld characters"
            static let issueLookingForTooLong = "Keep it under %ld characters"
            static let issuePriceOutOfRange = "Enter a price with at most two decimals"

            static func capacity(_ count: Int) -> String {
                String(format: capacityFormat, count)
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
                case .titleMissing: issueTitleMissing
                case .titleTooLong: String(format: issueTitleTooLong, limits.titleMaxLength)
                case .locationNameMissing: issueLocationNameMissing
                case .locationNameTooLong: String(format: issueLocationNameTooLong, limits.locationNameMaxLength)
                case .descriptionTooLong: String(format: issueDescriptionTooLong, limits.descriptionMaxLength)
                case .lookingForTooLong: String(format: issueLookingForTooLong, limits.lookingForMaxLength)
                default: nil
                }
            }

            /// When, where on the map, how many and how much.
            private static func valueMessage(for issue: EventDraft.Issue) -> String {
                let limits = AppConfig.Events.Creation.self
                return switch issue {
                case .startsAtTooSoon: String(format: issueStartsAtTooSoon, limits.minimumLeadTimeMinutes)
                case .coordinateMissing: issueCoordinateMissing
                case .capacityOutOfRange:
                    String(format: issueCapacityOutOfRange, limits.capacityRange.lowerBound, limits.capacityRange.upperBound)
                case .capacityBelowParticipants: issueCapacityBelowParticipants
                case .priceOutOfRange: issuePriceOutOfRange
                default: ""
                }
            }
        }

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

    /// Confirmation step of the email form, after a sign-up (or a sign-in refused as unconfirmed). `%@` is the email.
    static let confirmEmailTitle = "Check your email"
    static let confirmEmailSubtitleFormat = "We sent a code to %@"
    static let confirmationCodePlaceholder = "Confirmation code"
    static let confirmAction = "Confirm"
    static let resendCodeAction = "Resend code"
    static let backToSignInAction = "Back to sign in"

    static func confirmEmailSubtitle(email: String) -> String {
        String(format: confirmEmailSubtitleFormat, email)
    }

    /// Tab titles double as navigation titles.
    static let homeTitle = "Home"
    static let exploreTitle = "Explore"
    static let profileTitle = "Profile"

    static let exploreEmptyTitle = "Nothing yet"
    static let exploreEmptyMessage = "New games show up here as people create them."

    /// The Home tab: the caller's groups and games, and the states around them.
    enum Home {
        static let groupsSection = "Your groups"
        static let gamesSection = "Your games"
        static let noGroups = "No groups yet. Find one on Explore, or create your own."
        static let noGames = "Games you join or host will appear here."
        static let emptyTitle = "Nothing here yet"
        static let emptyMessage = "Games you join or host and groups you belong to appear here."
        static let exploreAction = "Explore"
        static let loadFailedTitle = "Couldn't load your groups and games"
        static let guestMessage = "Sign in to see your groups and the games you join or host."
        static let groupsLoadFailed = "Couldn't load your groups. Pull down to try again."
        static let gamesLoadFailed = "Couldn't load your games. Pull down to try again."
    }

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
