import Foundation

/// Where Explore's filter outlives the process: the last criteria the user set come back on the next launch.
protocol EventFilterStore {
    /// The stored filter, `nil` when none was saved (or the stored one no longer reads).
    func load() -> EventFilter?
    func save(_ filter: EventFilter)
    func clear()
}
