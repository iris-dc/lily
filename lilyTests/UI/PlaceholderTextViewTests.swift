import Testing
import UIKit
@testable import lily

/// The UIKit side of the composer's field: what it reports to accessibility, which keys it takes before the text
/// system does, and when it may take the keyboard.
@MainActor
struct PlaceholderTextViewTests {
    @Test func theValueIsThePlaceholderWhileEmptyAndTheTextOtherwise() {
        let view = PlaceholderTextView()
        view.placeholder = "Message"
        #expect(view.accessibilityValue == "Message")
        view.text = "Hello"
        #expect(view.accessibilityValue == "Hello")
    }

    @Test func returnAndKeypadEnterAreKeyCommandsWithPriority() {
        let commands = (PlaceholderTextView().keyCommands ?? []).filter { $0.input == "\r" }
        let flags = commands.map(\.modifierFlags)
        let prioritised = commands.allSatisfy(\.wantsPriorityOverSystemBehavior)
        #expect(flags == PlaceholderTextView.returnKeyFlags)
        #expect(prioritised)
    }

    /// Covered (UIKit's `willMove(toWindow: nil)` as the screen over it settles), the field declines the keyboard UIKit
    /// would hand back on the way back; a touch on it or the owner's `takeFocus()` opens it again.
    @Test func theKeyboardIsNotTakenBackAfterLeavingTheWindowUntilATouchOrTheOwnerAsks() {
        let view = PlaceholderTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        #expect(view.canBecomeFirstResponder)

        view.willMove(toWindow: nil)
        #expect(!view.canBecomeFirstResponder, "the field does not take the keyboard back by itself")
        _ = view.hitTest(CGPoint(x: 10, y: 10), with: nil)
        #expect(view.canBecomeFirstResponder, "a touch on the field opens it")

        view.willMove(toWindow: nil)
        _ = view.hitTest(CGPoint(x: 400, y: 10), with: nil)
        #expect(!view.canBecomeFirstResponder, "a touch beside the field does not")
        view.takeFocus()
        #expect(view.canBecomeFirstResponder, "the owner's word does")

        view.willMove(toWindow: nil)
        _ = view.accessibilityActivate()
        #expect(view.canBecomeFirstResponder, "an accessibility activation does")
    }
}
