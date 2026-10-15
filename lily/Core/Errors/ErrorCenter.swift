import Foundation
import Observation

/// An error currently shown in the shared popup. `id` changes per report so identical errors re-animate.
struct PresentedError: Identifiable, Equatable {
    let id: UUID
    let error: AppError
    let message: ErrorMessage
}

/// Single funnel for user-facing errors. The shared `ErrorPopup` observes `current`.
@Observable
final class ErrorCenter {
    private(set) var current: PresentedError?
    /// Popup mounts currently on screen, in presentation order. Only the last one draws, so an error raised while a
    /// sheet is up shows once above the sheet instead of twice (again, dimmed, on the root behind it).
    private(set) var presenters: [UUID] = []
    /// How long a popup stays before it dismisses itself; `nil` keeps it up until the user dismisses it (`-hold-popups`).
    let autoDismissDelay: Duration?
    private let logger: any Logging

    init(logger: any Logging, autoDismissDelay: Duration? = AppConfig.ErrorPopup.autoDismissDelay) {
        self.logger = logger
        self.autoDismissDelay = autoDismissDelay
    }

    /// Every presented error leaves an info line under `.ui`: the fault itself is logged where it happened, at its own
    /// level, so this line records only what the user was shown.
    func report(_ error: AppError) {
        logger.info(.ui, "Presenting error: \(error)")
        current = PresentedError(id: UUID(), error: error, message: ErrorMessageMapper.message(for: error))
    }

    func report(_ error: any Error) {
        report(AppError.wrapping(error))
    }

    func dismiss(_ id: PresentedError.ID? = nil) {
        guard id == nil || current?.id == id else { return }
        current = nil
    }

    /// A popup mount came on screen (root view or sheet root); it becomes the one that draws.
    func beginPresenting(_ presenter: UUID) {
        endPresenting(presenter)
        presenters.append(presenter)
    }

    func endPresenting(_ presenter: UUID) {
        presenters.removeAll { $0 == presenter }
    }

    func isTopPresenter(_ presenter: UUID) -> Bool {
        presenters.last == presenter
    }
}
