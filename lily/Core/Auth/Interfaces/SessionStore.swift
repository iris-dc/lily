import Foundation

/// Tiny on-device persistence for the session choice. Treated as a hint, never as the source of truth.
protocol SessionStore {
    func load() -> StoredSession?
    func save(_ session: StoredSession)
    func clear()
}
