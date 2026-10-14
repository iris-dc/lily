import Foundation

/// One of Home's lists at a glance: the shape `HomeOverviewState.resolve` judges, so the screen never reads a view
/// model's or store's flags itself.
nonisolated struct HomeListSnapshot: Equatable, Sendable {
    let isEmpty: Bool
    /// A load answered (content, empty or a failure) since the last reset; until then the list is still out.
    let hasAnswered: Bool
    let loadFailed: Bool
}

/// What one section of Home shows for its list.
nonisolated enum HomeSectionState: Equatable, Sendable {
    /// The list has not answered yet: a spinner in the section.
    case loading
    /// Nothing is loaded and the last load failed: a note saying so.
    case failed
    /// The list answered with nothing: a note saying so.
    case empty
    /// The rows or cards.
    case content
}

/// What the signed-in Home shows, decided from a snapshot of its three lists. The rule that matters: while any list
/// the screen waits for has not answered, the screen shows its spinner and never "Nothing here yet", or a caller whose
/// only content is a tournament would read that line until the last load landed. A list behind a feature flag that is
/// off is passed as `nil` and ignored.
nonisolated enum HomeOverviewState: Equatable, Sendable {
    /// Nothing is there yet and at least one list is still out: one spinner for the screen.
    case loading
    /// Every list answered with nothing; `loadFailed` when the games or the groups load failed, so the screen can say so.
    case empty(loadFailed: Bool)
    /// Something is there (or the tournaments load failed, whose note lives inside the sections): the sections, each
    /// with its own state. `groups` is `nil` with the groups flag off, `tournaments` whenever the section is hidden.
    case sections(groups: HomeSectionState?, tournaments: HomeSectionState?, games: HomeSectionState)

    static func resolve(events: HomeListSnapshot,
                        groups: HomeListSnapshot?,
                        tournaments: HomeListSnapshot?) -> HomeOverviewState {
        let present = [events, groups, tournaments].compactMap { $0 }
        if present.contains(where: { !$0.isEmpty }) || tournaments?.loadFailed == true {
            return .sections(groups: groups.map(sectionState),
                             tournaments: tournaments.flatMap(tournamentsSectionState),
                             games: sectionState(of: events))
        }
        if present.contains(where: { !$0.hasAnswered }) { return .loading }
        return .empty(loadFailed: events.loadFailed || groups?.loadFailed == true)
    }

    private static func sectionState(of list: HomeListSnapshot) -> HomeSectionState {
        if !list.isEmpty { return .content }
        if !list.hasAnswered { return .loading }
        return list.loadFailed ? .failed : .empty
    }

    /// Tournaments: shown only while the caller organises or plays in something, or the load failed. Most callers have
    /// none, so while it still loads behind other content the section stays hidden rather than spinning.
    private static func tournamentsSectionState(of list: HomeListSnapshot) -> HomeSectionState? {
        if !list.isEmpty { return .content }
        return list.loadFailed ? .failed : nil
    }
}
