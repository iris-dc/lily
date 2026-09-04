import Foundation

final class UserDefaultsSessionStore: SessionStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = AppConfig.Storage.Keys.storedSession) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> StoredSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
