import Foundation

/// Fetches a tournament by id and pushes its detail on the Chats stack (Home while chat is switched off), with a match's
/// sheet up when one is named: a tapped match reminder goes through it (the inbox's reminder card carries the name and
/// needs no fetch). A tournament that is gone or unreachable reaches the popup; cancellation stays quiet.
final class TournamentOpener {
    private let tournaments: any TournamentRepository
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging

    init(tournaments: any TournamentRepository, navigation: AppNavigation, reporter: GroupErrorReporter, logger: any Logging) {
        self.tournaments = tournaments
        self.navigation = navigation
        self.reporter = reporter
        self.logger = logger
    }

    /// `source` names what asked (a notification) in the warning when the tournament cannot be opened.
    @discardableResult
    func open(tournamentID: String, matchID: String?, from source: String) async -> Bool {
        do {
            let detail = try await tournaments.tournament(id: tournamentID)
            let destination = TournamentDestination(id: tournamentID, name: detail.tournament.name, matchID: matchID)
            if AppConfig.FeatureFlags.chat {
                navigation.openInChat(destination)
            } else {
                navigation.openInHome(destination)
            }
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            logger.warning(.tournaments, "Tournament \(tournamentID) behind \(source) is unavailable: \(error)")
            reporter.report(error)
            return false
        }
    }
}
