import Foundation

/// The people side of the group mock: who a user id names, and the direct conversation with them. Direct conversations
/// are private two-member groups of kind `direct` named after the person, under
/// `MockGroupFixtures.directConversationID(for:)`, so the chat, Mine and the rooms treat them like any group; the
/// fixtures ship one with Marta, which a start with her answers. A cleared conversation is hidden from Mine
/// (`hiddenConversationIDs`) until a new line or a replayed start brings it back, like the backend's `hiddenAt`.
extension MockGroupRepository {
    /// The name any roster gives `userID`, or `nil` for an id no fixture names.
    func displayName(ofUser userID: String) -> String? {
        rosters.values.lazy.flatMap { $0 }.first { $0.userId == userID }?.displayName
    }

    /// Like the backend: one conversation per pair, created on the first call and answered as it is on every later one;
    /// a replay brings a hidden conversation back into Mine.
    func startDirect(with userID: String, name: String) -> SportGroup {
        let id = MockGroupFixtures.directConversationID(for: userID)
        if let existing = find(id) {
            unhideConversation(id: id)
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

    /// A cleared conversation leaves Mine while nothing newer than the caller's floor was written; the room itself
    /// stays readable (it is open while it is cleared). A community is never hidden.
    func hideConversation(id: String) {
        guard find(id)?.isDirect == true else { return }
        hiddenConversationIDs.insert(id)
        logger.info(.groups, "Mock conversation \(id) hidden")
    }

    /// A new line in the room (either side's) or a replayed start: the conversation is back in Mine.
    func unhideConversation(id: String) {
        guard hiddenConversationIDs.remove(id) != nil else { return }
        logger.info(.groups, "Mock conversation \(id) back in Mine")
    }
}
