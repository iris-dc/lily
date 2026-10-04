import Foundation

nonisolated extension SportGroup {
    /// "34 members · Football", with `suffix` appended when given ("Active today" on a row, "Joined" on a tile). A
    /// direct conversation has no count or type worth a caption and reads "Direct message" instead; a tournament's room
    /// reads "Tournament · 6 players".
    func caption(suffix: String? = nil) -> String {
        guard isDirect || isTournamentRoom else {
            return AppBranding.Groups.groupCaption(memberCount: memberCount, type: type, suffix: suffix)
        }
        let lead = isDirect ? AppBranding.People.directMessage : AppBranding.Tournaments.roomCaption(players: memberCount)
        return AppBranding.Groups.caption([lead] + (suffix.map { [$0] } ?? []))
    }

    /// The mark of the room's row: a trophy for a tournament, the initials otherwise.
    var avatarSymbol: String? {
        isTournamentRoom ? DesignTokens.Symbols.tournament : nil
    }
}
