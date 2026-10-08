import SwiftUI
import Testing
@testable import lily

struct ReturnKeyPolicyTests {
    @Test func aPlainReturnSendsWhileTheDraftCanGo() {
        #expect(ReturnKeyPolicy.action(modifiers: [], canSend: true) == .send)
    }

    /// An empty or blocked draft swallows the key: the field must not grow by a blank line.
    @Test func aPlainReturnDoesNothingWhileTheDraftCannotGo() {
        #expect(ReturnKeyPolicy.action(modifiers: [], canSend: false) == .nothing)
    }

    @Test func shiftReturnIsANewlineWhateverTheDraftHolds() {
        #expect(ReturnKeyPolicy.action(modifiers: .shift, canSend: true) == .newline)
        #expect(ReturnKeyPolicy.action(modifiers: [.shift, .command], canSend: false) == .newline)
    }
}
