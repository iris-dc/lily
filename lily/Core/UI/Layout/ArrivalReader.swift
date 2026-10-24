import SwiftUI
import UIKit

extension View {
    /// Runs `arrived` once the transition that brought the screen on (a push, the pop back to it) has finished, or at
    /// once when it came on without one (a split view's detail, a tab switch), and `departed` when it leaves the window
    /// (covered by a push, another tab chosen). SwiftUI's `onAppear` runs as the push starts.
    func onArrival(perform arrived: @escaping () -> Void, onDeparture departed: @escaping () -> Void) -> some View {
        background(ArrivalReader(arrived: arrived, departed: departed))
    }
}

/// UIKit knows when a navigation transition ends: each time the reader's view joins a window, it asks the transition
/// coordinator of the view controller hosting it.
private struct ArrivalReader: UIViewRepresentable {
    let arrived: () -> Void
    let departed: () -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.isUserInteractionEnabled = false
        update(view)
        return view
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        update(view)
    }

    private func update(_ view: ReaderView) {
        view.arrived = arrived
        view.departed = departed
    }

    final class ReaderView: UIView {
        var arrived: (() -> Void)?
        var departed: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                departed?()
                return
            }
            // A coordinator that cannot take the completion (`false`) would never run it.
            let queued = hostingController?.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
                self?.arrived?()
            } ?? false
            if !queued { arrived?() }
        }

        private var hostingController: UIViewController? {
            sequence(first: self as UIResponder, next: \.next).first { $0 is UIViewController } as? UIViewController
        }
    }
}
