import Foundation

/// The people side of the group mock: who a user id names, and the direct conversation with them. Direct conversations
/// are private two-member groups of kind `direct` named after the person, under
/// `MockGroupFixtures.directConversationID(for:)`, so the chat, Mine and the rooms treat them like any group; the
/// fixtures ship one with Marta, which a start with her answers.
extension MockGroupRepository {
    /// The name any roster gives `userID`, or `nil` for an id no fixture names.
    func displayName(ofUser userID: String) -> String? {
        rosters.values.lazy.flatMap { $0 }.first { $0.userId == userID }?.displayName
    }

    /// Like the backend: one conversation per pair, created on the first call and answered as it is on every later one.
    func startDirect(with userID: String, name: String) -> SportGroup {
        let id = MockGroupFixtures.directConversationID(for: userID)
        if let existing = find(id) {
            logger.info(.groups, "Mock conversation \(id) replayed")
            return existing
        }
        let created = now()
        let conversation = MockGroupFixtures.conversation(with: Counterpart(userId: userID, displayName: name),
                                                          startedBy: AppBranding.Groups.Create.mockOwnerName,
                                                          at: created,
                                                          membership: GroupMembership(role: .member, joinedAt: created))
        groups.append(conversation)
        rosters[id] = [GroupMember(userId: userID, displayName: name, role: .member, joinedAt: created)]
        logger.info(.groups, "Mock conversation \(id) created with \(userID)")
        return conversation
    }
}
