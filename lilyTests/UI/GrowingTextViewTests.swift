import SwiftUI
import Testing
import UIKit
@testable import lily

/// The pure parts of the composer's field: how tall it is for its text, and how a UIKit key's modifiers read in SwiftUI.
struct GrowingTextViewTests {
    @Test func theHeightSpansOneLineToTheLineLimit() {
        let height = { GrowingTextView.Metrics.height(fitting: $0, lineHeight: 22, maxLines: 5) }
        #expect(height(0) == 22, "an empty field is one line tall")
        #expect(height(10) == 22)
        #expect(height(66) == 66, "three lines take three lines")
        #expect(height(400) == 110, "past the limit the field scrolls")
        #expect(GrowingTextView.Metrics.height(fitting: 400, lineHeight: 22, maxLines: 0) == 22, "a limit under one line is one")
    }

    /// The transcript answers a tap on the status bar; UIKit ignores the tap while a second scroll view claims it too.
    @MainActor
    @Test func theFieldLeavesTheStatusBarTapToTheTranscript() {
        #expect(PlaceholderTextView().scrollsToTop == false)
    }

    @Test func uiKitModifiersMapToSwiftUIOnes() {
        #expect(EventModifiers(UIKeyModifierFlags()).isEmpty)
        #expect(EventModifiers(.shift) == .shift)
        #expect(EventModifiers([.shift, .command]) == [.shift, .command])
        #expect(EventModifiers([.control, .alternate, .alphaShift, .numericPad]) == [.control, .option, .capsLock, .numericPad])
    }
}
