import Foundation

/// A choice in `UserDefaults` under `Choice.storageKey`. A stored value this build cannot read reads as the system
/// choice, so a shrunk list or a downgrade never leaves a Profile row blank, and is a warning naming the key, never the
/// value.
final class UserDefaultsChoiceStore<Choice: StoredChoice>: ChoiceStore {
    private let defaults: UserDefaults
    private let logger: any Logging

    init(defaults: UserDefaults = .standard, logger: any Logging) {
        self.defaults = defaults
        self.logger = logger
    }

    func load() -> Choice {
        let raw = defaults.string(forKey: Choice.storageKey)
        let choice = Choice(storedValue: raw)
        if let raw, raw != choice.storedValue {
            logger.warning(
                Choice.logCategory,
                "Stored value under \(Choice.storageKey) could not be read; following the system"
            )
        }
        return choice
    }

    func save(_ choice: Choice) {
        defaults.set(choice.storedValue, forKey: Choice.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Choice.storageKey)
    }
}
