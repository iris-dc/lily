import SwiftUI
import UIKit

/// The attachment viewer's drag to close, as a UIKit pan: it begins only for a drag more up or down than sideways
/// (`ViewerDismissal.beginsDismissal`), and the pager's own pan waits for it to fail, so a vertical drag never turns the
/// page and a sideways one turns it as before. A SwiftUI drag alongside the pager moved the page both ways at once.
struct ViewerDismissPan: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onChanged: (CGSize) -> Void
    /// The translation and the velocity at the end; a cancelled pan ends with no velocity and settles back.
    var onEnded: (_ translation: CGSize, _ velocity: CGSize, _ wasCancelled: Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // The pan begins once the finger has moved past its threshold: counted from there, the page does not jump.
        if recognizer.state == .began {
            recognizer.setTranslation(.zero, in: recognizer.view)
            return
        }
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        let moved = CGSize(width: translation.x, height: translation.y)
        switch recognizer.state {
        case .changed:
            onChanged(moved)
        case .ended:
            onEnded(moved, CGSize(width: velocity.x, height: velocity.y), false)
        case .cancelled:
            onEnded(moved, .zero, true)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return ViewerDismissal.beginsDismissal(velocity: CGSize(width: velocity.x, height: velocity.y))
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView
        }
    }
}
