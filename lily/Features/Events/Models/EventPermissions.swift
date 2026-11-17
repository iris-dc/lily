import Foundation

/// Who may do what on the event detail besides the join/leave control (`Participation`), decided in one place so the
/// action row and its tests agree; the tournament's `TournamentPermissions` pattern. Guests get nothing. The host and
/// every participant open the room's chat (while the flag is on) and invite while the event has not started; a join
/// after the start stays the backend's to allow, so only the invites close.
nonisolated struct EventPermissions: Equatable, Sendable {
    let canOpenChat: Bool
    let canInvite: Bool

    static let none = EventPermissions(canOpenChat: false, canInvite: false)

    /// The in-body action row under the facts: chat and invite, drawn only when it has something to offer.
    var showsActionRow: Bool { canOpenChat || canInvite }
}

/// The rule itself; in an extension so the memberwise init above stays synthesized.
nonisolated extension EventPermissions {
    init(event: SportEvent, userID: String?, now: Date, chatEnabled: Bool) {
        // The room's members: the host and everyone who joined.
        let isInvolved = userID != nil && (event.isHosted(by: userID) || event.participates)
        self.init(canOpenChat: chatEnabled && isInvolved,
                  canInvite: isInvolved && event.startsAt > now)
    }
}
