import Foundation

/// For the lists whose filter is not worth keeping (a group's games, My Events) and for previews: nothing is stored.
final class NoOpEventFilterStore: EventFilterStore {
    func load() -> EventFilter? { nil }

    func save(_ filter: EventFilter) {}

    func clear() {}
}
