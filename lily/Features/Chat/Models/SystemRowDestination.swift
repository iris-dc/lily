import Foundation

/// Where a tapped system row leads: the game it announced — the room's own game by id and name (the info button's
/// push, so the detail offers no Open chat back), any other by value — or the tournament it reports on (with the
/// match selected when the row names one).
nonisolated enum SystemRowDestination: Hashable, Sendable {
    case event(SportEvent)
    case eventRoom(EventDestination)
    case tournament(TournamentDestination)
}

extension SystemRowDestination {
    /// Every chat is on the Chats stack, which registers both destinations; the row pushes there.
    func open(through navigation: AppNavigation) {
        switch self {
        case .event(let event): navigation.openInChat(event)
        case .eventRoom(let destination): navigation.openInChat(destination)
        case .tournament(let destination): navigation.openInChat(destination)
        }
    }
}
