import Foundation

/// What a system row points at and what it changes: the repositories that answer the game behind an `event_created`
/// row and the tournament behind a tournament row, and the change counters the lists behind the chat reload on when
/// such a row arrives live. Held by `ChatViewModel` as one value.
struct SystemRowLinks {
    let events: any EventRepository
    let tournaments: any TournamentRepository
    let eventChanges: ChangeTracker
    let tournamentChanges: ChangeTracker

    /// A row announcing a game created elsewhere or a tournament's progress means the segments and lists behind this
    /// screen must reload; a text message changes nothing.
    func recordChange(for kind: MessageKind) {
        if kind == .eventCreated {
            eventChanges.recordChange()
        } else if kind.isTournamentNote {
            tournamentChanges.recordChange()
        }
    }
}

/// The games and tournaments behind the system rows on screen, fetched once each.
struct LinkedContent {
    var events: [String: SportEvent] = [:]
    var tournaments: [String: Tournament] = [:]
}
