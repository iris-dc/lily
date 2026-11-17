import Foundation

/// Copy of an event's chat room: the Chats caption and the loader behind the chat's info button. The action row and
/// the invite sheet reuse the groups' keys, the invite card the inbox's.
nonisolated extension AppBranding.Events {
    /// One event, as the room caption and the chat's info button name it; the form's section header shares the key.
    static var event: String { localized("Event") }
    /// The loader's gone state: deleted, or a private group's event the caller may no longer read.
    static var unavailable: String { localized("This event is no longer available") }
    static var detailLoadFailedTitle: String { localized("Couldn't load event") }

    /// "Event · 6 players": an event room's caption on Chats, the tournament room's pattern with the event mark.
    static func roomCaption(players: Int) -> String {
        AppBranding.Groups.caption([event, Create.capacity(players)])
    }
}
