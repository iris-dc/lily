import Foundation

/// The tombstone of a deleted account, and the pre-deletion summary's consequence marks.
nonisolated extension DesignTokens.Symbols {
    /// The fixed mark beside the localized "Deleted user" name (`Tombstone`).
    static let deletedUser = "person.slash"
    /// The delete summary's rows (`DeleteAccountSheet`): each mark names what the consequence touches — the words
    /// carry the verb, so the marks stay the domains' own glyphs (groups, games, tournaments, messages).
    static let deletionGroupsTransferring = "person.2"
    static let deletionGroupsDeleted = "person.2.slash"
    static let deletionEventsCancelled = "calendar"
    static let deletionEntriesWithdrawn = "trophy"
    /// Filled: the organizer's own tournaments, told from the entered ones.
    static let deletionTournamentsCancelled = "trophy.fill"
    static let deletionMessages = "bubble.left"
}
