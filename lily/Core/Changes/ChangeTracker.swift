import Observation

/// Counts changes made anywhere in the app to one kind of data. Each list remembers the count it loaded at, so a list
/// that missed a change (My Events, after a join made from Explore) reloads on its next appearance instead of waiting
/// out its TTL; views may observe `version` for the same purpose. One instance per kind, shared through `AppDependencies`.
@Observable
final class ChangeTracker {
    private(set) var version = 0

    func recordChange() {
        version += 1
    }
}
