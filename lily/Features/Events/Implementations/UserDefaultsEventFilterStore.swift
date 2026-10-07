import Foundation

/// Explore's filter in `UserDefaults`, under `AppConfig.Storage.Keys.eventFilter`, as `PersistedEventFilter` JSON.
/// A stored value that no longer decodes (a type this build dropped) reads as none, so the defaults apply. Hit, miss,
/// save and clear are logged under `.cache`; the criteria themselves never are.
final class UserDefaultsEventFilterStore: EventFilterStore {
    private let defaults: UserDefaults
    private let logger: any Logging
    private let key = AppConfig.Storage.Keys.eventFilter

    init(defaults: UserDefaults = .standard, logger: any Logging) {
        self.defaults = defaults
        self.logger = logger
    }

    func load() -> EventFilter? {
        guard let data = defaults.data(forKey: key) else {
            logger.debug(.cache, "No stored event filter; using the defaults")
            return nil
        }
        do {
            let filter = try JSONDecoder().decode(PersistedEventFilter.self, from: data).filter
            logger.info(.cache, "Event filter restored; active: \(filter.isActive)")
            return filter
        } catch {
            logger.warning(.cache, "Stored event filter could not be read; using the defaults: \(error)")
            return nil
        }
    }

    func save(_ filter: EventFilter) {
        do {
            defaults.set(try JSONEncoder().encode(PersistedEventFilter(filter)), forKey: key)
            logger.debug(.cache, "Event filter stored; active: \(filter.isActive)")
        } catch {
            logger.warning(.cache, "Event filter could not be stored: \(error)")
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
        logger.info(.cache, "Stored event filter cleared")
    }
}
