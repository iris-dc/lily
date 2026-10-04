import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct TournamentOpenerTests {
    private let tournaments = FakeTournamentRepository()
    private let navigation = AppNavigation()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let opener: TournamentOpener

    init() {
        errorCenter = ErrorCenter(logger: logger)
        opener = TournamentOpener(tournaments: tournaments,
                                  navigation: navigation,
                                  reporter: GroupErrorReporter(errorCenter: errorCenter) {},
                                  logger: logger)
    }

    @Test func aKnownTournamentIsFetchedForItsNameAndPushedOnTheChatsStack() async {
        tournaments.details["t1"] = .fixture(tournament: .fixture(id: "t1", name: "Kickers Cup"))

        let opened = await opener.open(tournamentID: "t1", matchID: "r01p002", from: "a test")

        #expect(opened && tournaments.fetchedIDs == ["t1"])
        #expect(navigation.selectedTab == .chat && navigation.chatPath.count == 1)
    }

    @Test func aGoneTournamentReachesThePopupWithOneWarning() async {
        let opened = await opener.open(tournamentID: "t1", matchID: nil, from: "a notification")

        #expect(!opened && navigation.chatPath.isEmpty)
        #expect(errorCenter.current?.error == .tournamentNotFound)
        #expect(logger.messages(in: .tournaments, at: .warning)
                == ["Tournament t1 behind a notification is unavailable: tournamentNotFound"])
    }
}
