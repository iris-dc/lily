import Foundation

/// Names one list's snapshot: which list, and whose. Mine, the caller's games and the `isJoined` flags on Explore are
/// one caller's answer, so a guest's Explore and each user's lists are kept apart.
nonisolated struct ListSnapshotKey: Hashable, Sendable {
    let list: String
    let userID: String?

    /// The file the snapshot lives in: list names are the app's own, user ids are Cognito subs.
    var fileName: String { "\(list).\(userID ?? AppConfig.Lists.guestSnapshotName).json" }
}

/// The last answer a list showed, kept on the device so the first frame of the next launch, and of a tab opened before
/// its load answered, shows it while the fresh answer loads. A hint, never the truth: every list still loads on its own
/// rules and replaces it. Cleared with the session, so one account's lists never show for the next.
protocol ListSnapshotStore: SessionObserver {
    func load<Value: Decodable>(_ type: Value.Type, for key: ListSnapshotKey) -> Value?
    func save<Value: Encodable>(_ value: Value, for key: ListSnapshotKey)
    func clear()
}
