import Foundation

nonisolated extension SportGroup {
    /// "34 members · Football", with `suffix` appended when given ("Active today" on a row, "Joined" on a tile). A
    /// direct conversation has no count or type worth a caption and reads "Direct message" instead; a tournament's
    /// room reads "Tournament · 6 players" and an event's room "Event · 6 players".
    func caption(suffix: String? = nil) -> String {
        guard let lead = roomCaptionLead else {
            return AppBranding.Groups.groupCaption(memberCount: memberCount, type: type, suffix: suffix)
        }
        return AppBranding.Groups.caption([lead] + (suffix.map { [$0] } ?? []))
    }

    /// The first caption part of a room that is no community; `nil` for a group, whose caption is its count and type.
    private var roomCaptionLead: String? {
        if isDirect { return AppBranding.People.directMessage }
        if isTournamentRoom { return AppBranding.Tournaments.roomCaption(players: memberCount) }
        if isEventRoom { return AppBranding.Events.roomCaption(players: memberCount) }
        return nil
    }

    /// "Görlitzer Park · 1,2 km": where the group plays, with the distance when the position is known; `nil` for a
    /// group without a place.
    func placeCaption(distance: String?) -> String? {
        location.map { AppBranding.Groups.caption([$0.name] + (distance.map { [$0] } ?? [])) }
    }

    /// The mark of the room's row: a trophy for a tournament, a calendar for an event, the initials otherwise.
    var avatarSymbol: String? {
        if isTournamentRoom { return DesignTokens.Symbols.tournament }
        if isEventRoom { return DesignTokens.Symbols.game }
        return nil
    }
}
