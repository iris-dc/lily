import UIKit

/// Ends editing in the key window and, when that sends the software keyboard down, waits for it to be gone (at most
/// `timeout`), so what opens next starts from the screen's settled layout. A field with a hardware keyboard, or no field
/// at all, answers at once: no keyboard goes, so no wait. A cover presented over a field only hides its keyboard, and
/// UIKit gives it back as the cover goes; a field that gave it up first has nothing to get back.
enum KeyboardDismissal {
    static func dismissAndWait(atMost timeout: Duration) async {
        let center = NotificationCenter.default
        let seen = KeyboardGoing()
        // Posted on the main thread while the field resigns, before `endEditing` returns.
        let observer = center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { seen.isGoing = true }
        }
        keyWindow?.endEditing(true)
        center.removeObserver(observer)
        guard seen.isGoing else { return }
        try? await Deadline.within(timeout) {
            for await _ in center.notifications(named: UIResponder.keyboardDidHideNotification) {
                return
            }
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

/// Whether the keyboard started going while editing ended.
private final class KeyboardGoing {
    var isGoing = false
}
