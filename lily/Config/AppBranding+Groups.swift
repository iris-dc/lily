import Foundation

nonisolated extension AppBranding {
    /// Copy of the groups screens, the group detail, the create sheet and the invite sheet.
    enum Groups {
        static var title: String { localized("Groups") }
        static var discover: String { localized("Discover") }
        static var discoverTitle: String { localized("Discover groups") }
        static var seeAll: String { localized("See all") }
        static var publicVisibility: String { localized("Public") }
        static var privateVisibility: String { localized("Private") }
        static var publicFooter: String { localized("Anyone can find and join") }
        static var privateFooter: String { localized("Only people who are invited can join") }
        static var openChat: String { localized("Open chat") }
        static var invite: String { localized("Invite") }
        static var createGame: String { localized("Create game") }
        static var joinGroup: String { localized("Join group") }
        static var groupFull: String { localized("Group is full") }
        static var inviteOnly: String { localized("Invite only") }
        static var unavailable: String { localized("This group is no longer available") }
        static var discoverEmptyTitle: String { localized("Nothing found") }
        static var discoverEmptyMessage: String { localized("Try another name or event type.") }
        static var eventsEmptyTitle: String { localized("No games yet") }
        static var eventsSection: String { localized("Events") }
        static var membersSection: String { localized("Members") }
        static var bannedSection: String { localized("Banned") }
        static var youSuffix: String { localized("You") }
        static var joinedCaption: String { localized("Joined") }
        static var activeTodayCaption: String { localized("Active today") }
        /// Under "Hosted in" for a private group's game: the link is withheld, the name stays.
        static var membersOnly: String { localized("Members only") }
        static var unread: String { localized("Unread messages") }
        static var eventsEmptyMessage: String { localized("Games created in this group show up here.") }
        static var unavailableMessage: String { localized("It may have been deleted, or it is private.") }
        static var loadFailedTitle: String { localized("Couldn't load group") }
        static var loadFailedMessage: String { localized("Check your connection and try again.") }
        static var tryAgain: String { localized("Try again") }
        /// Roles as members see them.
        static var ownerRole: String { localized("Owner") }
        static var adminRole: String { localized("Admin") }
        static var memberRole: String { localized("Member") }
        /// Toolbar menu and member actions, with the confirmations the destructive ones ask for.
        static var edit: String { localized("Edit") }
        static var leave: String { localized("Leave group") }
        static var delete: String { localized("Delete group") }
        static var reportGroup: String { localized("Report group") }
        static var makeAdmin: String { localized("Make admin") }
        static var removeAdmin: String { localized("Remove admin") }
        static var removeMember: String { localized("Remove") }
        static var banMember: String { localized("Ban") }
        static var unbanMember: String { localized("Unban") }

        static func members(_ count: Int) -> String {
            localized("\(count) members")
        }

        static func joinConfirmation(groupName: String) -> String {
            localized("Join \(groupName)?")
        }

        static func hostedIn(groupName: String) -> String {
            localized("Hosted in \(groupName)")
        }

        static func ownedBy(name: String) -> String {
            localized("Run by \(name)")
        }

        /// The confirmations the destructive toolbar and member actions ask for.
        static func leaveConfirmation(groupName: String) -> String {
            localized("Leave \(groupName)?")
        }

        static func deleteConfirmation(groupName: String) -> String {
            localized("Delete \(groupName)? Its chat is deleted too.")
        }

        static func removeConfirmation(memberName: String) -> String {
            localized("Remove \(memberName) from the group?")
        }

        static func banConfirmation(memberName: String) -> String {
            localized("Ban \(memberName)? They cannot rejoin.")
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
            static var title: String { localized("New group") }
            static var editTitle: String { localized("Edit group") }
            static var submit: String { localized("Create group") }
            static var save: String { localized("Save") }
            static var cancel: String { localized("Cancel") }
            static var groupSection: String { localized("Group") }
            static var permissionsSection: String { localized("Members may") }
            static var membersCanCreateEvents: String { localized("Create games") }
            static var membersCanInvite: String { localized("Invite people") }
            static var anyType: String { localized("Any type") }
            static var nameField: String { localized("Name") }
            static var namePlaceholder: String { localized("Kreuzberg Kickers") }
            static var descriptionPlaceholder: String { localized("What the group is about") }
            static var eventType: String { localized("Event type") }
            static var visibility: String { localized("Who can join") }
            /// The mock repository has no profile to read the owner's name from; the backend stamps the real one.
            static var mockOwnerName: String { localized("You") }

            /// The line under a field for one issue, naming the limit from `AppConfig.Groups`.
            static func message(for issue: GroupDraft.Issue) -> String {
                let limits = AppConfig.Groups.self
                return switch issue {
                case .nameTooShort: localized("Give the group a name of at least \(limits.nameLength.lowerBound) characters")
                case .nameTooLong: localized("Keep the name under \(limits.nameLength.upperBound) characters")
                case .descriptionTooLong: localized("Keep the description under \(limits.descriptionMaxLength) characters")
                }
            }
        }

        /// The sheet that invites people the caller shares a group or a game with; the invitee answers from their inbox.
        enum Invite {
            static var title: String { localized("Invite people") }
            static var done: String { localized("Done") }
            static var searchPrompt: String { localized("Search people") }
            /// The row's button before and after the invite went out.
            static var send: String { localized("Invite") }
            static var sent: String { localized("Invited") }
            static var emptyTitle: String { localized("Nobody to invite yet") }
            static var emptyMessage: String { localized("People you share a group or a game with show up here.") }
            static var noMatchesTitle: String { localized("Nobody found") }
            static var noMatchesMessage: String { localized("Try another name.") }
            static var loadFailedTitle: String { localized("Couldn't load people") }

            /// Where the caller knows the person from: the shared group's name, or the shared game's title.
            static func viaGroup(_ name: String) -> String {
                localized("In \(name)")
            }

            static func viaEvent(_ title: String) -> String {
                localized("Played \(title)")
            }
        }
    }
}

nonisolated extension AppBranding.Events.Create {
    /// The Group row of the event form: the picker's label, and its choice for a game of the host's own.
    static var group: String { localized("Group") }
    static var noGroup: String { localized("No group") }
    /// Footer under a read-only "No group" row: the caller is in groups, but none lets them host.
    static var noEligibleGroups: String { localized("Your groups let only their admins host games.") }
}
