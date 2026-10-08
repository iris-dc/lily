import SwiftUI

/// What a hardware Return in the composer does: sends the draft, inserts a newline, or nothing. Shift+Return is the
/// newline whatever the draft holds; a plain Return sends while the draft can go and is swallowed otherwise, so an
/// empty field never grows by a blank line. The software keyboard never reaches this: its Return keeps inserting
/// newlines in the multi-line field.
nonisolated enum ReturnKeyPolicy {
    enum Action: Equatable, Sendable {
        case send
        case newline
        case nothing
    }

    static func action(modifiers: EventModifiers, canSend: Bool) -> Action {
        if modifiers.contains(.shift) {
            return .newline
        }
        return canSend ? .send : .nothing
    }
}
