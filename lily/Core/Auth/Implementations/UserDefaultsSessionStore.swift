import Foundation

final class UserDefaultsSessionStore: SessionStore {
    private let defaults: UserDefaults
    private let logger: any Logging
    private let key = AppConfig.Storage.Keys.storedSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, logger: any Logging) {
        self.defaults = defaults
        self.logger = logger
    }

    func load() -> StoredSession? {
        guard let data = defaults.data(forKey: key) else {
            logger.debug(.cache, "Session cache miss")
            return nil
        }
        do {
            let session = try decoder.decode(StoredSession.self, from: data)
            logger.debug(.cache, "Session cache hit")
            return session
        } catch {
            logger.warning(.cache, "Stored session unreadable, discarding: \(error)")
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    func save(_ session: StoredSession) {
        do {
            let data = try encoder.encode(session)
            defaults.set(data, forKey: key)
        } catch {
            logger.error(.cache, "Storing session failed: \(error)")
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
        logger.debug(.cache, "Session cache invalidated")
    }
}
