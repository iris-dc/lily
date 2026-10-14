import Foundation

/// What the event, group and tournament forms share when they send a new thing once. `clientID` travels with every
/// attempt, so a retry after a lost answer finds what the backend already stored instead of creating a second one; a
/// failure that leaves the outcome unknown (`leavesOutcomeUnknown`: a 500 or a lost connection, because the backend
/// commits before it answers) is settled by looking the thing up under that id: ours (`isOurs`: hosted, owned or
/// organised by the caller) means the create landed and nothing is shown; `notFound` is the check's answer (the create
/// did not land, a debug line, never a warning); anyone else's or a failed lookup keeps the failure. Every kept
/// failure goes to `report`; a cancellation (the sheet was dismissed) stays quiet.
///
/// Built once per view model in its `init`, like `WriteGate`: SwiftLint caps a function at five non-defaulted
/// parameters, and the collaborators plus the work would be more.
struct CreateFlow<Created: Identifiable> where Created.ID == String {
    /// The thing in log lines, lower-case ("event").
    let noun: String
    let category: LogCategory
    let logger: any Logging
    let report: (any Error) -> Void
    let leavesOutcomeUnknown: (AppError) -> Bool
    let notFound: AppError
    let lookup: (String) async throws -> Created
    let isOurs: (Created) -> Bool

    /// Answers what was created, sent or found landed, or `nil` after a reported failure or a cancellation.
    /// `describe` gives the success line its tail ("(8 spots) in group g"), ids only.
    func submit(clientID: String,
                describing describe: (Created) -> String,
                send: () async throws -> Created) async -> Created? {
        do {
            let created = try await send()
            logger.info(category, "\(noun.capitalized) created \(created.id) \(describe(created))")
            return created
        } catch {
            guard !AppError.isCancellation(error) else { return nil }
            logger.error(category, "Create failed for \(noun) \(clientID): \(error)")
            if let landed = await stored(clientID, despite: error) {
                logger.info(category, "Create landed for \(noun) \(landed.id) despite \(error)")
                return landed
            }
            report(error)
            return nil
        }
    }

    /// What the backend holds under `clientID` when the failure leaves the outcome unknown and it is the caller's.
    private func stored(_ clientID: String, despite error: any Error) async -> Created? {
        guard let appError = error as? AppError, leavesOutcomeUnknown(appError) else { return nil }
        do {
            let stored = try await lookup(clientID)
            return isOurs(stored) ? stored : nil
        } catch let lookupError as AppError where lookupError == notFound {
            logger.debug(category, "No \(noun) of ours under \(clientID); the create did not land")
            return nil
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(category, "Could not check whether \(noun) \(clientID) landed after \(appError)")
            }
            return nil
        }
    }
}
