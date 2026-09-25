import Foundation

/// A group's detail reached from its chat (`GroupDetailContext.fromChat`), distinct from the group itself so the
/// stack can tell the two pushes apart and hide "Open chat" on this one.
nonisolated struct GroupInfoDestination: Hashable, Sendable {
    let group: SportGroup
}
