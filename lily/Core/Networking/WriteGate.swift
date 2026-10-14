import Foundation

/// The frame around one backend write a screen makes: a `TRY_AGAIN` is repeated once through `LostRace`, a
/// cancellation (the screen was dismissed) stays quiet, any other failure is logged under `category` as
/// "<what> failed: <error>" (at warning when `isExpected` names it a product state the screen shows, else at error)
/// and handed to `report` (an `ErrorCenter` or a `GroupErrorReporter`, so `TERMS_REQUIRED` still raises the terms
/// sheet). `run` answers whether the write went through, so a sheet can close on success. The busy flag stays at
/// the call site: every screen has its own shape (a Bool, a set of ids) and some release it before a prompt.
///
/// Built once per view model in its `init`: SwiftLint caps a function at five non-defaulted parameters, and the
/// four collaborators plus the work would be six.
struct WriteGate {
    let category: LogCategory
    let logger: any Logging
    let tryAgainDelay: Duration
    let report: (any Error) -> Void
    var isExpected: (AppError) -> Bool = { _ in false }

    @discardableResult
    func run(_ what: String, _ work: () async throws -> Void) async -> Bool {
        do {
            try await LostRace.attemptTwice(delay: tryAgainDelay, logger: logger, category: category, retrying: what, work)
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            log(failure: error, of: what)
            report(error)
            return false
        }
    }

    private func log(failure error: any Error, of what: String) {
        let message = "\(what) failed: \(error)"
        if let appError = error as? AppError, isExpected(appError) {
            logger.warning(category, message)
        } else {
            logger.error(category, message)
        }
    }
}
