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
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func report(_ error: AppError) {
        logger.error(.ui, "Presenting error: \(error)")
        current = PresentedError(id: UUID(), error: error, message: ErrorMessageMapper.message(for: error))
    }

    func report(_ error: any Error) {
        report(AppError.wrapping(error))
    }

    func dismiss(_ id: PresentedError.ID? = nil) {
        guard id == nil || current?.id == id else { return }
        current = nil
    }
}
