import Foundation

/// A Profile choice kept in `UserDefaults` as one string: the word `AppConfig.Storage.systemChoiceValue` to follow the
/// system, or the choice's code. A value this build cannot read (a language it does not ship, a currency no longer
/// offered) reads as the system choice.
nonisolated protocol StoredChoice: Hashable, Sendable {
    static var storageKey: String { get }
    static var logCategory: LogCategory { get }
    /// Nothing stored, or a value this build does not know, is the system choice.
    init(storedValue: String?)
    var storedValue: String { get }
}
