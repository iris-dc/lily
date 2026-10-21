import Testing
import UIKit
@testable import lily

/// The UIKit side of the composer's field: what it reports to accessibility and which keys it takes before the text
/// system does.
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
}
