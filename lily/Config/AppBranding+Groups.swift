import Foundation

nonisolated extension AppBranding {
    /// Copy of the Groups tab, the group detail, the create sheet and the invite sheets.
    enum Groups {
        static let title = "Groups"
        static let mine = "Mine"
        static let discover = "Discover"
        static let publicVisibility = "Public"
        static let privateVisibility = "Private"
        static let publicFooter = "Anyone can find and join"
        static let privateFooter = "Only people with an invite can join"
        static let oneMemberFormat = "%ld member"
        static let membersFormat = "%ld members"
        /// What the Groups tab's badge means to assistive technology (the badge itself is not exposed).
        static let oneUnreadRoom = "1 unread room"
        static let unreadRoomsFormat = "%ld unread rooms"
        static let openChat = "Open chat"
        static let invite = "Invite"
        static let createGame = "Create game"
        static let joinGroup = "Join group"
        static let groupFull = "Group is full"
        static let inviteOnly = "Invite only"
        static let joinWithCode = "Join with code"
        static let joinConfirmationFormat = "Join %@?"
        static let unavailable = "This group is no longer available"
        static let emptyTitle = "No groups yet"
        static let emptyMessage = "Create one or discover public groups"
        static let discoverEmptyTitle = "Nothing found"
        static let discoverEmptyMessage = "Try another name or event type."
        static let eventsEmptyTitle = "No games yet"
        static let eventsSection = "Events"
        static let membersSection = "Members"
        static let bannedSection = "Banned"
        static let youSuffix = "You"
        static let joinedCaption = "Joined"
        static let activeTodayCaption = "Active today"
        static let hostedInFormat = "Hosted in %@"
        /// Under "Hosted in" for a private group's game: the link is withheld, the name stays.
        static let membersOnly = "Members only"
        static let ownedByFormat = "Run by %@"
        static let unread = "Unread messages"
        static let guestMineMessage = "Sign in to see your groups and chat with them."
        static let eventsEmptyMessage = "Games created in this group show up here."
        static let unavailableMessage = "It may have been deleted, or it is private."
        static let loadFailedTitle = "Couldn't load group"
        static let loadFailedMessage = "Check your connection and try again."
        static let tryAgain = "Try again"
        /// Roles as members see them.
        static let ownerRole = "Owner"
        static let adminRole = "Admin"
        static let memberRole = "Member"
        /// Toolbar menu and member actions, with the confirmations the destructive ones ask for.
        static let edit = "Edit"
        static let leave = "Leave group"
        static let leaveConfirmationFormat = "Leave %@?"
        static let delete = "Delete group"
        static let deleteConfirmationFormat = "Delete %@? Its chat is deleted too."
        static let reportGroup = "Report group"
        static let makeAdmin = "Make admin"
        static let removeAdmin = "Remove admin"
        static let removeMember = "Remove"
        static let banMember = "Ban"
        static let unbanMember = "Unban"
        static let removeConfirmationFormat = "Remove %@ from the group?"
        static let banConfirmationFormat = "Ban %@? They cannot rejoin."

        static func members(_ count: Int) -> String {
            String(format: count == 1 ? oneMemberFormat : membersFormat, count)
        }

        static func unreadRooms(_ count: Int) -> String {
            count == 1 ? oneUnreadRoom : String(format: unreadRoomsFormat, count)
        }

        static func joinConfirmation(groupName: String) -> String {
            String(format: joinConfirmationFormat, groupName)
        }

        static func hostedIn(groupName: String) -> String {
            String(format: hostedInFormat, groupName)
        }

        static func ownedBy(name: String) -> String {
            String(format: ownedByFormat, name)
        }

        /// Caption parts joined with the dot every card uses ("34 members · Football · Active today").
        static func caption(_ parts: [String]) -> String {
            parts.joined(separator: AppBranding.Events.captionSeparator)
        }

        enum Create {
            /// VoiceOver label of the floating "+".
            static let button = "Create a group"
            static let title = "New group"
            static let editTitle = "Edit group"
            static let submit = "Create group"
            static let save = "Save"
            static let cancel = "Cancel"
            static let groupSection = "Group"
            static let permissionsSection = "Members may"
            static let membersCanCreateEvents = "Create games"
            static let membersCanInvite = "Invite people"
            static let anyType = "Any type"
            static let nameField = "Name"
            static let namePlaceholder = "Kreuzberg Kickers"
            static let descriptionPlaceholder = "What the group is about"
            static let eventType = "Event type"
            static let visibility = "Who can join"
            static let issueNameTooShort = "Give the group a name of at least %ld characters"
            static let issueNameTooLong = "Keep the name under %ld characters"
            static let issueDescriptionTooLong = "Keep the description under %ld characters"
            /// The mock repository has no profile to read the owner's name from; the backend stamps the real one.
            static let mockOwnerName = "You"

            /// The line under a field for one issue, naming the limit from `AppConfig.Groups`.
            static func message(for issue: GroupDraft.Issue) -> String {
                let limits = AppConfig.Groups.self
                return switch issue {
                case .nameTooShort: String(format: issueNameTooShort, limits.nameLength.lowerBound)
                case .nameTooLong: String(format: issueNameTooLong, limits.nameLength.upperBound)
                case .descriptionTooLong: String(format: issueDescriptionTooLong, limits.descriptionMaxLength)
                }
            }
        }

        enum Invite {
            static let title = "Invite people"
            static let expiry = "Expires"
            static let expiryDaysFormat = "%ld days"
            static let expiryOneDay = "1 day"
            static let uses = "Can be used by"
            static let unlimitedUses = "Anyone with the link"
            static let oneUse = "One person"
            static let limitedUsesFormat = "Up to %ld"
            static let share = "Share link"
            static let copyCode = "Copy code"
            static let codeCopied = "Code copied"
            static let revoke = "Revoke"
            static let codeField = "Invite code"
            static let codePlaceholder = "KRZB-7K3M-QX9P"
            static let codePrompt = "Enter the code from your invite."
            static let redeem = "Continue"
            static let back = "Back"
            static let done = "Done"
            static let previewTitle = "You're invited"
            static let alreadyMember = "You're already in this group"
            static let expiresAtFormat = "Expires %@"
            static let shareTextFormat = "Join %@ on lily"

            static func shareText(groupName: String) -> String {
                String(format: shareTextFormat, groupName)
            }

            static func expiryLabel(days: Int) -> String {
                days == 1 ? expiryOneDay : String(format: expiryDaysFormat, days)
            }

            static func expiresAt(_ dateText: String) -> String {
                String(format: expiresAtFormat, dateText)
            }

            static func usesLabel(_ uses: Int) -> String {
                switch uses {
                case 0: unlimitedUses
                case 1: oneUse
                default: String(format: limitedUsesFormat, uses)
                }
            }
        }
    }
}

nonisolated extension AppBranding.Events.Create {
    /// The Group row of the event form: the picker's label, and its choice for a game of the host's own.
    static let group = "Group"
    static let noGroup = "No group"
}
