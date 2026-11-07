import Foundation

/// The deletion contract's tombstone: the one mapping from the wire's additive `deleted` flag (message sender, event
/// host, tournament organizer, entry member) to what every surface shows, so the localized name and the mark never
/// drift between features. Old backends omit the flag; absent reads as not deleted.
nonisolated enum Tombstone {
    /// The name a surface shows over a stored snapshot: the localized "Deleted user" once the account behind it is gone.
    static func displayName(_ snapshot: String, deleted: Bool?) -> String {
        deleted == true ? AppBranding.DeletedUser.name : snapshot
    }

    /// The fixed mark drawn beside a tombstoned name.
    static var symbol: String { DesignTokens.Symbols.deletedUser }
}
