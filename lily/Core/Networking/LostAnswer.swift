import Foundation

/// The read-back after a write whose answer was lost. The backend commits before it answers, so a lost connection or
/// the route's 5xx fallback (`leavesOutcomeUnknown`) says nothing about the outcome: the fresh state is fetched
/// (`refetch`), shown (`apply`, so the screen agrees with the backend before any popup) and asked whether it carries
/// the caller's intent. A refusal that means the screen was stale (`isWorthAnotherLook`) is read back and shown too,
/// but the backend's word that nothing changed is never read as landed.
struct LostAnswer<State> {
    enum Settlement: Equatable {
        /// The fresh state shows the intent: nothing to report.
        case landed
        /// The fresh state says the write did not land, or the backend refused it: the failure stands.
        case didNotLand
        /// Nothing was learnt: the failure was neither unknown nor worth a look, the read-back failed or the caller was
        /// cancelled meanwhile, or the fresh state cannot tell (the item is gone from the page).
        case unresolved

        var isLanded: Bool { self == .landed }
    }

    let category: LogCategory
    let logger: any Logging
    let leavesOutcomeUnknown: (AppError) -> Bool
    var isWorthAnotherLook: (AppError) -> Bool = { _ in false }
    let refetch: () async throws -> State
    /// Runs on every successful read-back, landed or not.
    let apply: (State) -> Void

    /// `what` names the write in log lines, ids only ("Pinning message m1"); `intent` reads the fresh state and answers
    /// `nil` when it cannot tell.
    func settle(_ what: String, despite error: any Error, intent: (State) -> Bool?) async -> Settlement {
        guard let appError = error as? AppError else { return .unresolved }
        let isUnknown = leavesOutcomeUnknown(appError)
        guard isUnknown || isWorthAnotherLook(appError) else { return .unresolved }
        announce(what, appError, isUnknown: isUnknown)
        guard let fresh = await readBack(what) else { return .unresolved }
        // A caller cancelled during the read-back (the sheet dismissed, the session ended) gets no state and no popup.
        guard !Task.isCancelled else { return .unresolved }
        apply(fresh)
        guard isUnknown else { return .didNotLand }
        switch intent(fresh) {
        case true?:
            logger.info(category, "\(what) landed despite \(appError); nothing to report")
            return .landed
        case false?:
            return .didNotLand
        case nil:
            return .unresolved
        }
    }

    private func announce(_ what: String, _ error: AppError, isUnknown: Bool) {
        if isUnknown {
            logger.warning(category, "\(what) outcome unknown (\(error)); reading back")
        } else {
            logger.info(category, "Reading back after \(error) on \(what)")
        }
    }

    /// `nil` when the read-back failed; a cancellation stays quiet.
    private func readBack(_ what: String) async -> State? {
        do {
            return try await refetch()
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(category, "Could not read back after \(what): \(error)")
            }
            return nil
        }
    }
}
