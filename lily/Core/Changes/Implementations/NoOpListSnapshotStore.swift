import Foundation

/// Keeps nothing: a mock run (previews, UI tests) stays in memory throughout, and a list that is no tab's (a group's
/// segments, Discover's own page) is built when its screen opens and needs no first frame from the disk.
final class NoOpListSnapshotStore: ListSnapshotStore {
    func load<Value: Decodable>(_ type: Value.Type, for key: ListSnapshotKey) -> Value? { nil }

    func save<Value: Encodable>(_ value: Value, for key: ListSnapshotKey) {}

    func clear() {}

    func sessionDidEnd() {}
}
