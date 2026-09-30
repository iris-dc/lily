import Foundation

nonisolated extension AppBranding {
    /// Copy of the groups screens, the group detail, the create sheet and the invite sheet.
    enum Groups {
        static let title = "Groups"
        static let discover = "Discover"
        static let discoverTitle = "Discover groups"
        static let seeAll = "See all"
        static let publicVisibility = "Public"
        static let privateVisibility = "Private"
        static let publicFooter = "Anyone can find and join"
        static let privateFooter = "Only people who are invited can join"
        static let oneMemberFormat = "%ld member"
        static let membersFormat = "%ld members"
        static let openChat = "Open chat"
        static let invite = "Invite"
        static let createGame = "Create game"
        static let joinGroup = "Join group"
        static let groupFull = "Group is full"
        static let inviteOnly = "Invite only"
        static let joinConfirmationFormat = "Join %@?"
        static let unavailable = "This group is no longer available"
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

        /// A group's caption from its count and type, with `suffix` appended when given ("Active today" on a row,
        /// "Joined" on a tile); `SportGroup` and `GroupSummary` both format through here.
        static func groupCaption(memberCount: Int, type: EventType?, suffix: String? = nil) -> String {
            var parts = [members(memberCount)]
            if let type { parts.append(type.displayName) }
            if let suffix { parts.append(suffix) }
            return caption(parts)
        }

        enum Create {
            /// The create sheet's title; the "+" menu on Explore names its group item after it.
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

        /// The sheet that invites people the caller shares a group or a game with; the invitee answers from their inbox.
        enum Invite {
            static let title = "Invite people"
            static let done = "Done"
            static let searchPrompt = "Search people"
            /// The row's button before and after the invite went out.
            static let send = "Invite"
            static let sent = "Invited"
            /// `%@` the shared group's name / the shared game's title.
            static let viaGroupFormat = "In %@"
            static let viaEventFormat = "Played %@"
            static let emptyTitle = "Nobody to invite yet"
            static let emptyMessage = "People you share a group or a game with show up here."
            static let noMatchesTitle = "Nobody found"
            static let noMatchesMessage = "Try another name."
            static let loadFailedTitle = "Couldn't load people"

            static func viaGroup(_ name: String) -> String {
                String(format: viaGroupFormat, name)
            }

            static func viaEvent(_ title: String) -> String {
                String(format: viaEventFormat, title)
            }
        }
    }
}

nonisolated extension AppBranding.Events.Create {
    /// The Group row of the event form: the picker's label, and its choice for a game of the host's own.
    static let group = "Group"
    static let noGroup = "No group"
    /// Footer under a read-only "No group" row: the caller is in groups, but none lets them host.
    static let noEligibleGroups = "Your groups let only their admins host games."
}
