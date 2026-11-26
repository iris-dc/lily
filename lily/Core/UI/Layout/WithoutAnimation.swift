import SwiftUI

/// Runs a state change with implicit animations disabled, so everything it moves lands in the same frame: a reveal
/// that half-animates shows the new rows at once while the controls beneath drift after them. It holds in a plain
/// `ScrollView`; a `Form` row that resizes slides its content regardless, so a fold inside a `Form` inserts a row.
func withoutAnimation(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
}
