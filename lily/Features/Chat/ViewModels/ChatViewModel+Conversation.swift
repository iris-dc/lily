import Foundation

/// What a direct conversation changes on the chat screen: nothing under the room's name (the title, the other person,
/// already says who is in, where a group shows its member count), and the other person's profile counts as reached
/// from this chat, so it offers no "Message" back into the room it was opened from.
extension ChatViewModel {
    var subtitle: String? {
        group.isDirect ? nil : AppBranding.Groups.members(group.memberCount)
    }

    /// Where a sender's name and avatar lead; every chat is on a stack that registers the destination.
    func profile(of row: MessageRow) -> UserProfileDestination {
        let isCounterpart = row.message.senderUserId == group.counterpart?.userId
        return UserProfileDestination(userId: row.message.senderUserId,
                                      displayName: row.senderName,
                                      context: isCounterpart ? .fromChat : .standalone)
    }
}
