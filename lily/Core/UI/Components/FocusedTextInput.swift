import UIKit

/// The field holding the keyboard, whichever it is. A SwiftUI field that has shown the keyboard's inline prediction
/// keeps its text when its binding is cleared, so the chat composer empties the field itself after a send, as an edit
/// of the user's would: the prediction is committed and the whole text replaced, which the field reports back through
/// its binding like any keystroke. Without a focused field there is nothing to do; the binding alone clears it.
@MainActor
enum FocusedTextInput {
    static func clear() {
        guard let input = firstResponder as? UITextInput,
              let everything = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument) else { return }
        input.unmarkText()
        input.replace(everything, withText: "")
    }

    private static var firstResponder: UIResponder? {
        UIApplication.shared.connectedScenes
            .lazy
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .compactMap(\.firstResponderDescendant)
            .first
    }
}

private extension UIView {
    var firstResponderDescendant: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.firstResponderDescendant { return found }
        }
        return nil
    }
}
