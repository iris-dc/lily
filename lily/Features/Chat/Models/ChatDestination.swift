import Foundation

/// A group's chat as a navigation destination, distinct from the group itself so one stack can hold both.
nonisolated struct ChatDestination: Hashable, Sendable {
    let group: SportGroup
}
