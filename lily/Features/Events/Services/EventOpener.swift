import Foundation

/// Fetches a game by id and pushes its detail on the Chats stack (Home while chat is switched off): the inbox's
/// reminder card and a tapped reminder notification both go through it. A game that is gone or unreachable reaches
/// the popup; cancellation stays quiet.
final class EventOpener {
    private let events: any EventRepository
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging

    init(events: any EventRepository, navigation: AppNavigation, reporter: GroupErrorReporter, logger: any Logging) {
        self.events = events
        self.navigation = navigation
        self.reporter = reporter
        self.logger = logger
    }

    /// `source` names what asked (a reminder, a notification) in the warning when the game cannot be opened.
    @discardableResult
    func open(eventID: String, from source: String) async -> Bool {
        do {
            let event = try await events.event(id: eventID)
            if AppConfig.FeatureFlags.chat {
                navigation.openInChat(event)
            } else {
                navigation.openInHome(event)
            }
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            logger.warning(.events, "Event \(eventID) behind \(source) is unavailable: \(error)")
            reporter.report(error)
            return false
        }
    }
}
