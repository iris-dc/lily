import Foundation
import Observation

/// Drives the landing screen: a preview of real upcoming events and the two ways into the app.
@Observable
final class LandingViewModel {
    private(set) var previewEvents: [SportEvent] = []
    var isSignInPresented = false

    private let session: SessionController
    private let repository: any EventRepository
    private let logger: any Logging

    init(session: SessionController, repository: any EventRepository, logger: any Logging) {
        self.session = session
        self.repository = repository
        self.logger = logger
    }

    /// Preview is decorative: on failure the landing still works, so nothing is shown to the user. Leaving the
    /// landing mid-load cancels the request, which is not a failure and stays at debug.
    func loadPreview() async {
        do {
            let events = try await repository.events(in: .upcoming)
            previewEvents = Array(events.prefix(AppConfig.Events.landingPreviewCount))
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.events, "Landing preview load cancelled")
                return
            }
            logger.warning(.events, "Landing preview unavailable: \(error)")
        }
    }

    func enterApp() { session.continueAsGuest() }
    func presentSignIn() { isSignInPresented = true }
}
