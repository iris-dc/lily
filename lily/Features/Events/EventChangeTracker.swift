import Foundation

/// Counts participation changes made anywhere in the app. Each list remembers the count it loaded at, so a list that
/// missed a change (My Events, after a join made from Explore) reloads on its next appearance instead of waiting out
/// `AppConfig.Events.listStaleAfter`. One instance, shared through `AppDependencies`.
final class EventChangeTracker {
    private(set) var version = 0

    func recordChange() {
        version += 1
    }
}
