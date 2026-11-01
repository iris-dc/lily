import Foundation

/// The one send of a new event, group or tournament. `clientID` travels with every attempt, so a repeat after a lost
/// answer finds what the backend already stored instead of creating a second one. A `TRY_AGAIN` is repeated once like
/// every other write (`LostRace`). A failure that leaves the outcome unknown (`leavesOutcomeUnknown`: a 500 or a lost
/// connection; the backend commits before it answers) is settled by looking the thing up under that id: ours (`isOurs`)
/// means the create landed and nothing is shown, `notFound` means it did not, anyone else's or a failed lookup keeps the
/// failure. A `*_ID_REUSED` (`.createIdReused`: our earlier create landed with other details and its answer was lost)
/// sends the draft as an update under the same id, so the one stored item carries every field the PUT carries (a caller
/// logs what its PUT cannot). Every kept failure goes to `report`; a cancellation (the sheet was dismissed) stays quiet.
struct CreateFlow<Created: Identifiable> where Created.ID == String {
    /// The thing in log lines, lower-case ("event").
    let noun: String
    let category: LogCategory
    let logger: any Logging
    let tryAgainDelay: Duration
    var sleep: Sleep = systemSleep
    let report: (any Error) -> Void
    let leavesOutcomeUnknown: (AppError) -> Bool
    let notFound: AppError
    let lookup: (String) async throws -> Created
    let isOurs: (Created) -> Bool

    /// Answers what was created, updated, sent or found landed, or `nil` after a reported failure or a cancellation.
    /// `describe` gives the success line its tail ("(8 spots) in group g"), ids only.
    func submit(clientID: String,
                describing describe: (Created) -> String,
                send: () async throws -> Created,
                update: () async throws -> Created) async -> Created? {
        do {
            let created = try await attemptTwice("Create", clientID, send)
            logger.info(category, "\(noun.capitalized) created \(created.id) \(describe(created))")
            return created
        } catch AppError.createIdReused {
            return await updated(clientID, update)
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

    /// Laurel refuses to answer the old body under a reused id, so every field the PUT carries goes onto the one stored
    /// item.
    private func updated(_ clientID: String, _ update: () async throws -> Created) async -> Created? {
        logger.warning(category, "Create of \(noun) \(clientID) was repeated with other details; updating it")
        do {
            let updated = try await attemptTwice("Update", clientID, update)
            logger.info(category, "\(noun.capitalized) \(updated.id) updated with the latest details")
            return updated
        } catch {
            guard !AppError.isCancellation(error) else { return nil }
            logger.error(category, "Update after a reused id failed for \(noun) \(clientID): \(error)")
            report(error)
            return nil
        }
    }

    private func attemptTwice(_ verb: String, _ clientID: String, _ attempt: () async throws -> Created) async throws -> Created {
        try await LostRace.attemptTwice(delay: tryAgainDelay,
                                        sleep: sleep,
                                        logger: logger,
                                        category: category,
                                        retrying: "\(verb) \(noun) \(clientID)",
                                        attempt)
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
